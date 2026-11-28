// MapLibre GL JS rendering for the Map view: library loading, basemaps, boundary and
// event layers, popups and camera. It knows nothing about seasons, search or filters;
// site/map.js passes it GeoJSON and listens for marker and cluster clicks.

import {maplibreVersion} from '../vendor/maplibre-gl/version.js';

const library = '/vendor/maplibre-gl/maplibre-gl';
// The contiguous states. Alaska and Hawaii are a pan or zoom away.
export const unitedStates = [[-124.9, 24.4], [-66.9, 49.5]];
const empty = {type: 'FeatureCollection', features: []};
const eventLayers = ['solar-venues', 'solar-clusters'];
const densityMaxZoom = 8;
const palettes = {
  light: {state: '#667aa3', county: '#9aa8c2', upcoming: '#1650d0', past: '#69758d', ring: '#f28a00'},
  dark: {state: '#8ea4cf', county: '#566a91', upcoming: '#3f7dff', past: '#7b879e', ring: '#ffb020'},
  satellite: {state: '#ffffff', county: '#f4e9b0', upcoming: '#1c5cf0', past: '#59647a', ring: '#ffc53d'},
};

let libraryPromise;

function loadStylesheet() {
  return new Promise((resolve, reject) => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = library + '.css?v=' + maplibreVersion;
    link.onload = resolve;
    link.onerror = () => {
      link.remove();
      reject(new Error('The map stylesheet could not load.'));
    };
    // Ahead of the site stylesheet, so the site's popup and control styles win.
    document.head.insertBefore(link, document.head.querySelector('link[rel="stylesheet"]'));
  });
}

// A failed import() stays failed for that URL, so a retry asks for a fresh one.
let attempts = 0;
function loadLibrary() {
  libraryPromise ||= Promise.all([
    import(library + '.mjs?v=' + maplibreVersion + (attempts++ ? '&retry=' + attempts : '')),
    loadStylesheet(),
  ]).then(([module]) => module).catch((error) => {
    libraryPromise = undefined;
    throw error;
  });
  return libraryPromise;
}

const styleCache = new Map();

async function fetchStyle(url) {
  if (!styleCache.has(url)) {
    const request = fetch(url, {signal: AbortSignal.timeout(15000)}).then((response) => {
      if (!response.ok) throw new Error('Basemap request failed (' + response.status + ').');
      return response.json();
    });
    styleCache.set(url, request);
    request.catch(() => styleCache.delete(url));
  }
  return structuredClone(await styleCache.get(url));
}

// Satellite is the imagery with the vector basemap's place, road and water names on top.
export function satelliteStyle(base, imagery) {
  const labelled = new Set(['place', 'transportation_name', 'water_name']);
  const labels = base.layers.filter((layer) => layer.type === 'symbol' &&
    labelled.has(layer['source-layer']) && !layer.id.includes('shield'));
  const vector = base.layers.find((layer) => layer['source-layer'] === 'boundary')?.source;
  const sources = {imagery: {type: 'raster', tiles: [imagery.tiles], tileSize: 256,
    maxzoom: imagery.maxzoom, attribution: imagery.attribution}};
  for (const id of new Set([vector, ...labels.map((layer) => layer.source)])) {
    if (id) sources[id] = base.sources[id];
  }
  return {
    ...base,
    sources,
    layers: [
      {id: 'imagery', type: 'raster', source: 'imagery'},
      ...labels.map((layer) => ({...layer, paint: {...layer.paint, 'text-color': '#ffffff',
        'text-halo-color': 'rgba(8,16,32,.85)', 'text-halo-width': 1.4}})),
    ],
    // Used only to find the boundary source, which no remaining layer references.
    metadata: {...base.metadata, 'solar:boundary-source': vector},
  };
}

// Use a font the provider's glyph server is known to have.
function labelFont(layers) {
  const fonts = layers.map((layer) => layer.layout?.['text-font'])
    .filter((font) => Array.isArray(font) && font.every((name) => typeof name === 'string' && name.includes(' ')));
  return fonts.find((font) => /bold/i.test(font[0])) || fonts[0] || ['Noto Sans Regular'];
}

// Credits sit behind an (i) button until it is pressed. MapLibre's compact control opens
// itself when the first credits arrive unless it is already marked compact.
function addCollapsedAttribution(maplibre, map) {
  map.addControl(new maplibre.AttributionControl({compact: true}), 'bottom-right');
  const control = map.getContainer().querySelector('.maplibregl-ctrl-attrib');
  control.classList.add('maplibregl-compact');
  control.classList.remove('maplibregl-compact-show');
  control.removeAttribute('open');
}

/**
 * Creates the map once; later changes go through the returned methods.
 * Rejects when the library, the basemap or WebGL is unavailable.
 */
export async function createEventMap({container, config, basemap = 'light', onVenue, onCluster, onZoom,
  describe, onNotice}) {
  const available = (name) => name === 'satellite' ? Boolean(config.satellite) : Boolean(config.styles[name]);
  let current = available(basemap) ? basemap : 'light';

  async function styleFor(name) {
    return name === 'satellite' ? satelliteStyle(await fetchStyle(config.styles.light), config.satellite) :
      fetchStyle(config.styles[name]);
  }

  // A saved basemap that has stopped working must not take the whole map down.
  const initialStyle = () => styleFor(current).catch((error) => {
    if (current === 'light') throw error;
    current = 'light';
    return styleFor(current);
  });
  const [maplibre, style] = await Promise.all([loadLibrary(), initialStyle()]);
  const map = new maplibre.Map({
    container,
    style,
    bounds: unitedStates,
    fitBoundsOptions: {padding: 20},
    minZoom: 1.5,
    maxZoom: 18,
    dragRotate: false,
    pitchWithRotate: false,
    touchPitch: false,
    attributionControl: false,
  });
  addCollapsedAttribution(maplibre, map);
  map.touchZoomRotate.disableRotation();
  map.keyboard.disableRotation();

  let data = empty;
  let focus = empty;
  let density = false;
  let counties = false;
  let popup;
  let tooltip;
  let styleRequest = 0;
  let warnings = 0;

  function visibility(id, shown) {
    if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', shown ? 'visible' : 'none');
  }

  // Density mode swaps markers for a heatmap until the map is zoomed in far enough.
  function applyDensity() {
    visibility('solar-density', density);
    for (const id of ['solar-cluster-halo', 'solar-clusters', 'solar-cluster-count', 'solar-venues', 'solar-venue-count']) {
      if (map.getLayer(id)) map.setLayerZoomRange(id, density ? densityMaxZoom : 0, 24);
    }
  }

  function addOverlays() {
    if (map.getSource('solar-venues')) return;
    const {layers, metadata} = map.getStyle();
    const colors = palettes[current];
    const font = labelFont(layers);
    const boundarySource = layers.find((layer) => layer['source-layer'] === 'boundary')?.source ||
      metadata?.['solar:boundary-source'];
    const firstLabel = layers.find((layer) => layer.type === 'symbol')?.id;

    // State and county lines come from the basemap's own vector tiles (OpenMapTiles
    // schema), so no boundary files are downloaded. Other schemas keep their own lines.
    if (boundarySource && map.getSource(boundarySource)) {
      const lines = (id, level, minzoom, paint) => map.addLayer({id, type: 'line', source: boundarySource,
        'source-layer': 'boundary', minzoom,
        filter: ['all', ['==', ['get', 'admin_level'], level], ['!=', ['get', 'maritime'], 1]],
        layout: {'line-join': 'round'}, paint}, firstLabel);
      lines('solar-county-lines', 6, 8, {'line-color': colors.county, 'line-width': .8, 'line-dasharray': [3, 2]});
      lines('solar-state-lines', 4, 0, {'line-color': colors.state,
        'line-width': ['interpolate', ['linear'], ['zoom'], 3, .8, 8, 1.6, 14, 2.4]});
      visibility('solar-county-lines', counties);
    }
    // The default dark style's place names are too faint to read comfortably.
    if (current === 'dark') {
      for (const layer of layers) {
        if (layer.type === 'symbol' && layer['source-layer'] === 'place') {
          map.setPaintProperty(layer.id, 'text-color', '#aebbd4');
        }
      }
    }
    // State names from the first zoom that shows the whole country.
    for (const layer of layers) {
      if (layer['source-layer'] === 'place' && /state/.test(layer.id)) {
        map.setLayerZoomRange(layer.id, Math.min(layer.minzoom ?? 0, 3), layer.maxzoom ?? 24);
      }
    }

    map.addSource('solar-venues', {type: 'geojson', data, cluster: true, clusterRadius: 46, clusterMaxZoom: 11,
      clusterProperties: {events: ['+', ['get', 'count']], upcoming: ['max', ['get', 'upcoming']]}});
    map.addSource('solar-density', {type: 'geojson', data});
    map.addSource('solar-focus', {type: 'geojson', data: focus});

    map.addLayer({id: 'solar-density', type: 'heatmap', source: 'solar-density', maxzoom: densityMaxZoom + 1,
      paint: {
        'heatmap-weight': ['interpolate', ['linear'], ['get', 'count'], 0, 0, 10, 1],
        'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 2, .7, densityMaxZoom, 2],
        'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 2, 12, densityMaxZoom, 42],
        'heatmap-color': ['interpolate', ['linear'], ['heatmap-density'], 0, 'rgba(40,110,230,0)',
          .15, 'rgba(60,130,235,.55)', .4, '#35b6c9', .65, '#f4d35e', 1, '#e4572e'],
        'heatmap-opacity': ['interpolate', ['linear'], ['zoom'], densityMaxZoom - 1, .85, densityMaxZoom + 1, 0],
      }}, firstLabel);

    const status = ['case', ['==', ['get', 'upcoming'], 1], colors.upcoming, colors.past];
    const clustered = ['has', 'point_count'];
    const radius = ['step', ['get', 'events'], 15, 10, 19, 50, 24, 150, 29];
    const countText = (id, filter, value) => map.addLayer({id, type: 'symbol', source: 'solar-venues', filter,
      layout: {'text-field': ['to-string', ['get', value]], 'text-font': font, 'text-size': 12,
        'text-allow-overlap': true, 'text-ignore-placement': true},
      paint: {'text-color': '#ffffff'}});
    map.addLayer({id: 'solar-cluster-halo', type: 'circle', source: 'solar-venues', filter: clustered,
      paint: {'circle-color': status, 'circle-opacity': .22, 'circle-radius': ['+', radius, 6]}});
    map.addLayer({id: 'solar-clusters', type: 'circle', source: 'solar-venues', filter: clustered,
      paint: {'circle-color': status, 'circle-radius': radius, 'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff'}});
    countText('solar-cluster-count', clustered, 'events');
    map.addLayer({id: 'solar-venues', type: 'circle', source: 'solar-venues', filter: ['!', clustered],
      paint: {'circle-color': status, 'circle-radius': ['case', ['>', ['get', 'count'], 1], 12, 8],
        'circle-stroke-width': 2.5, 'circle-stroke-color': '#ffffff'}});
    countText('solar-venue-count', ['all', ['!', clustered], ['>', ['get', 'count'], 1]], 'count');
    // The hovered and selected locations are drawn separately, so they show even when clustered.
    const selected = ['==', ['get', 'kind'], 'selected'];
    map.addLayer({id: 'solar-focus-ring', type: 'circle', source: 'solar-focus',
      paint: {'circle-color': colors.ring, 'circle-opacity': ['case', selected, .28, .14],
        'circle-radius': ['case', selected, 20, 17], 'circle-stroke-color': colors.ring,
        'circle-stroke-width': ['case', selected, 3.5, 2]}});
    map.addLayer({id: 'solar-focus-dot', type: 'circle', source: 'solar-focus', filter: selected,
      paint: {'circle-color': colors.ring, 'circle-radius': 5, 'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 1.5}});
    applyDensity();
  }

  function featureAt(point) {
    const layers = eventLayers.filter((id) => map.getLayer(id));
    if (!layers.length) return null;
    const slack = 5;
    return map.queryRenderedFeatures([[point.x - slack, point.y - slack], [point.x + slack, point.y + slack]],
      {layers})[0];
  }

  function hideTooltip() {
    tooltip?.remove();
    tooltip = undefined;
    map.getCanvas().style.cursor = '';
  }

  map.on('click', async (event) => {
    const feature = featureAt(event.point);
    if (!feature) return;
    hideTooltip();
    const {cluster_id: cluster, point_count: points, key} = feature.properties;
    if (cluster === undefined) {
      onVenue(key);
      return;
    }
    const source = map.getSource('solar-venues');
    const center = feature.geometry.coordinates;
    try {
      const [zoom, leaves] = await Promise.all([source.getClusterExpansionZoom(cluster),
        source.getClusterLeaves(cluster, points, 0)]);
      onCluster(leaves.map((leaf) => leaf.properties.key));
      map.easeTo({center, zoom: Math.min(zoom + .3, map.getMaxZoom())});
    } catch {
      // The data changed while the cluster was being read; the next click sees the new one.
    }
  });

  map.on('mousemove', (event) => {
    const feature = featureAt(event.point);
    if (!feature) {
      hideTooltip();
      return;
    }
    map.getCanvas().style.cursor = 'pointer';
    if (popup) return;
    const text = describe(feature.properties);
    if (!text) return;
    tooltip ||= new maplibre.Popup({closeButton: false, closeOnClick: false, offset: 18, className: 'map-tooltip'});
    tooltip.setLngLat(feature.geometry.coordinates).setText(text).addTo(map);
  });
  map.on('mouseout', hideTooltip);
  map.on('movestart', hideTooltip);
  map.on('zoom', () => onZoom(map.getZoom(), map.getMinZoom(), map.getMaxZoom()));
  // Some basemap styles name icons their sprite lacks; draw nothing for those.
  map.setMissingStyleImageResolver((id) => {
    if (!map.hasImage(id)) map.addImage(id, {width: 1, height: 1, data: new Uint8Array(4)});
  });
  map.on('error', (event) => {
    if (warnings++ < 5) console.warn('Map:', event.error?.message || event);
    if (event.sourceId && !String(event.sourceId).startsWith('solar-')) {
      onNotice('Some map tiles could not load.');
    }
  });

  try {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('The map took too long to start.')), 20000);
      map.once('style.load', () => {
        clearTimeout(timeout);
        resolve();
      });
    });
    addOverlays();
  } catch (error) {
    map.remove();
    throw error;
  }
  map.on('style.load', addOverlays);
  onZoom(map.getZoom(), map.getMinZoom(), map.getMaxZoom());

  function closePopup() {
    const open = popup;
    popup = undefined;
    open?.remove();
  }

  return {
    get basemap() { return current; },
    setData(collection) {
      data = collection;
      hideTooltip();
      map.getSource('solar-venues')?.setData(data);
      map.getSource('solar-density')?.setData(data);
    },
    setFocus(points) {
      focus = {type: 'FeatureCollection', features: points.map(({coordinates, kind}) =>
        ({type: 'Feature', geometry: {type: 'Point', coordinates}, properties: {kind}}))};
      map.getSource('solar-focus')?.setData(focus);
    },
    // The old basemap stays on screen unless the new one downloads.
    async setBasemap(name) {
      if (!available(name)) return current;
      const request = ++styleRequest;
      if (name === current) return current;
      const next = await styleFor(name);
      if (request !== styleRequest) return current;
      current = name;
      map.setStyle(next, {diff: false});
      return current;
    },
    setDensity(shown) {
      density = shown;
      applyDensity();
    },
    setCounties(shown) {
      counties = shown;
      visibility('solar-county-lines', shown);
    },
    showPopup(coordinates, content, onClose) {
      hideTooltip();
      closePopup();
      const next = new maplibre.Popup({offset: 22, maxWidth: 'min(300px, 82vw)', className: 'event-popup',
        closeOnClick: false, focusAfterOpen: false});
      next.setLngLat(coordinates).setDOMContent(content).addTo(map);
      next.on('close', () => {
        if (popup !== next) return;
        popup = undefined;
        onClose();
      });
      popup = next;
    },
    closePopup,
    flyTo(coordinates) {
      // Below centre, leaving room for the popup above the marker.
      map.flyTo({center: coordinates, zoom: Math.max(map.getZoom(), 12.5), speed: 1.4,
        offset: [0, Math.min(110, map.getContainer().clientHeight / 5)]});
    },
    // Pans only as far as needed to make room for a popup on a clicked marker.
    reveal(coordinates) {
      const {x, y} = map.project(coordinates);
      const {clientWidth: width, clientHeight: height} = map.getContainer();
      if (x < 150 || x > width - 150 || y < Math.min(250, height * .55) || y > height - 30) {
        map.easeTo({center: coordinates, offset: [0, Math.min(110, height / 5)]});
      }
    },
    fitBounds(bounds) {
      map.fitBounds(bounds, {padding: 60, maxZoom: 12.5});
    },
    zoomIn: () => map.zoomIn(),
    zoomOut: () => map.zoomOut(),
    reset() {
      map.fitBounds(unitedStates, {padding: 20});
    },
    resize: () => map.resize(),
    destroy() {
      closePopup();
      hideTooltip();
      map.remove();
    },
    // The underlying MapLibre instance, for debugging and browser tests.
    map,
  };
}
