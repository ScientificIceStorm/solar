// Map provider settings. The defaults need no account or key. A deployment can override
// them with environment variables served by /api/map-config (see site/_worker.js and
// docs/event-map.md).

export const defaultConfig = Object.freeze({
  styles: Object.freeze({
    light: 'https://tiles.openfreemap.org/styles/liberty',
    dark: 'https://tiles.openfreemap.org/styles/dark',
  }),
  // USGS The National Map orthoimagery: public domain, no key, United States coverage.
  satellite: Object.freeze({
    tiles: 'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Imagery: <a href="https://www.usgs.gov/programs/national-geospatial-program/national-map" target="_blank" rel="noopener">USDA, USGS The National Map</a>',
    maxzoom: 16,
  }),
});

const secureUrl = (value) => typeof value === 'string' && value.startsWith('https://') ? value : null;

export function mergeConfig(overrides) {
  const styles = {
    light: secureUrl(overrides?.styles?.light) || defaultConfig.styles.light,
    dark: secureUrl(overrides?.styles?.dark) || defaultConfig.styles.dark,
  };
  const custom = overrides?.satellite;
  let satellite = defaultConfig.satellite;
  if (custom === false) satellite = null;
  // Custom imagery is only used with its own attribution; USGS credit would be wrong for it.
  else if (secureUrl(custom?.tiles) && custom.attribution) {
    satellite = {tiles: custom.tiles, attribution: String(custom.attribution),
      maxzoom: Number(custom.maxzoom) || 18};
  }
  return {styles, satellite};
}

export async function loadMapConfig(fetcher = fetch) {
  try {
    const response = await fetcher('/api/map-config', {signal: AbortSignal.timeout(4000)});
    return mergeConfig(response.ok ? await response.json() : null);
  } catch {
    return mergeConfig(null);
  }
}
