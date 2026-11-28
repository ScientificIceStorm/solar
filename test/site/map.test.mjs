import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';

import worker from '../../site/_worker.js';
import {defaultConfig, loadMapConfig, mergeConfig} from '../../site/map/config.js';
import {coordinates, eventBounds, filterEvents, groupVenues, usEvents, venueFeatures} from '../../site/map/events.js';
import {satelliteStyle} from '../../site/map/view.js';

// Synthetic fixtures for tests only; the site shows nothing but API data.
const event = (sku, latitude, longitude, extra = {}) => ({sku, name: 'Event ' + sku,
  start: '2026-10-10T04:00:00Z', end: '2026-10-10T04:00:00Z',
  location: {city: 'Fresno', country: 'United States', latitude, longitude}, ...extra});
const now = Date.parse('2026-11-01T00:00:00Z');

test('keeps U.S. events with a SKU, in date order', () => {
  const rows = [event('B', 1, 1, {start: '2026-12-01'}), event('A', 1, 1),
    event('C', 1, 1, {location: {country: 'Canada'}}), event('', 1, 1)];
  assert.deepEqual(usEvents(rows).map((row) => row.sku), ['A', 'B']);
});

test('reads coordinates as [longitude, latitude] and rejects unusable ones', () => {
  assert.deepEqual(coordinates(event('A', 36.7, -119.8)), [-119.8, 36.7]);
  for (const bad of [[undefined, undefined], [null, -100], [0, 0], [95, -100], ['36', '-119']]) {
    assert.equal(coordinates(event('A', ...bad)), null, String(bad));
  }
});

test('filters by name, city or SKU and by date', () => {
  const rows = [event('RE-1', 36, -119), event('RE-2', 36, -119, {start: '2026-12-05', end: '2026-12-06',
    location: {city: 'Austin', country: 'US'}})];
  const skus = (options) => filterEvents(rows, {now, ...options}).map((row) => row.sku);
  assert.deepEqual(skus({query: ' austin '}), ['RE-2']);
  assert.deepEqual(skus({query: 're-1'}), ['RE-1']);
  assert.deepEqual(skus({when: 'upcoming'}), ['RE-2']);
  assert.deepEqual(skus({when: 'past'}), ['RE-1']);
  assert.deepEqual(skus({when: 'all', query: 'nothing'}), []);
});

test('an event stays upcoming through its last day', () => {
  const rows = [event('A', 1, 1, {start: '2026-10-31T00:00:00Z', end: '2026-10-31T00:00:00Z'})];
  assert.equal(filterEvents(rows, {when: 'upcoming', now: Date.parse('2026-10-31T23:00:00Z')}).length, 1);
  assert.equal(filterEvents(rows, {when: 'upcoming', now}).length, 0);
});

test('groups events sharing a location into one weighted feature', () => {
  const rows = [event('A', 36, -119), event('B', 36, -119, {end: '2027-01-01'}), event('C', 40, -100),
    event('D', null, null)];
  const features = venueFeatures(groupVenues(rows), now).features;
  assert.deepEqual(features.map((feature) => [feature.properties.count, feature.properties.upcoming]),
    [[2, 1], [1, 0]]);
  assert.deepEqual(eventBounds(rows), [[-119, 36], [-100, 40]]);
  assert.equal(eventBounds([rows[3]]), null);
});

test('provider overrides need HTTPS, and imagery needs its own attribution', () => {
  assert.equal(mergeConfig(null).styles.light, defaultConfig.styles.light);
  assert.equal(mergeConfig({styles: {light: 'http://insecure'}}).styles.light, defaultConfig.styles.light);
  assert.equal(mergeConfig({styles: {dark: 'https://tiles.example/dark.json'}}).styles.dark,
    'https://tiles.example/dark.json');
  assert.equal(mergeConfig({satellite: false}).satellite, null);
  assert.equal(mergeConfig({satellite: {tiles: 'https://x/{z}'}}).satellite, defaultConfig.satellite);
});

test('falls back to the default providers when the config request fails', async () => {
  const config = await loadMapConfig(async () => { throw new Error('offline'); });
  assert.deepEqual(config.styles, defaultConfig.styles);
  assert.deepEqual((await loadMapConfig(async () => new Response('', {status: 404}))).styles, defaultConfig.styles);
});

const ask = async (env) => (await worker.fetch(new Request('https://skyloft.tech/api/map-config'), env, {})).json();

test('the worker serves map settings only from environment variables', async () => {
  assert.deepEqual(await ask({}), {styles: {}});
  assert.deepEqual(await ask({MAP_STYLE_LIGHT_URL: 'https://t.example/s.json?key={key}', MAP_API_KEY: 'a b',
    MAP_SATELLITE_TILES_URL: 'none'}), {styles: {light: 'https://t.example/s.json?key=a%20b'}, satellite: false});
  // A template without its key is ignored rather than sent to the provider broken.
  assert.deepEqual(await ask({MAP_STYLE_DARK_URL: 'https://t.example/d?key={key}'}), {styles: {}});
  // The key is never exposed unless a configured URL uses it.
  assert.ok(!JSON.stringify(await ask({MAP_API_KEY: 'secret'})).includes('secret'));
});

test('satellite style keeps imagery plus basemap labels', () => {
  const style = satelliteStyle({sources: {vector: {type: 'vector'}, relief: {type: 'raster'}}, layers: [
    {id: 'background', type: 'background'},
    {id: 'border', type: 'line', source: 'vector', 'source-layer': 'boundary'},
    {id: 'city', type: 'symbol', source: 'vector', 'source-layer': 'place'},
    {id: 'poi', type: 'symbol', source: 'vector', 'source-layer': 'poi'},
  ]}, defaultConfig.satellite);
  assert.deepEqual(style.layers.map((layer) => layer.id), ['imagery', 'city']);
  assert.deepEqual(Object.keys(style.sources), ['imagery', 'vector']);
  assert.equal(style.metadata['solar:boundary-source'], 'vector');
});

test('vendored MapLibre matches the installed package (run npm run build)', async () => {
  const root = new URL('../../', import.meta.url);
  const clean = (text) => text.replace(/\r\n/g, '\n')
    .replace(/\n?(\/\/|\/\*)# sourceMappingURL=\S+( \*\/)?\s*$/, '').trimEnd();
  for (const name of ['maplibre-gl.mjs', 'maplibre-gl-worker.mjs', 'maplibre-gl.css']) {
    const [vendored, installed] = await Promise.all([
      readFile(new URL('site/vendor/maplibre-gl/' + name, root), 'utf8'),
      readFile(new URL('node_modules/maplibre-gl/dist/' + name, root), 'utf8'),
    ]);
    assert.ok(clean(vendored) === clean(installed), name + ' is out of date');
  }
  const {maplibreVersion} = await import('../../site/vendor/maplibre-gl/version.js');
  const {dependencies} = JSON.parse(await readFile(new URL('package.json', root), 'utf8'));
  assert.equal(maplibreVersion, dependencies['maplibre-gl']);
});
