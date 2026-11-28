# Event map

The Map view (`/#map`) shows the selected season's U.S. VEX V5 events on a [MapLibre GL JS](https://maplibre.org/maplibre-gl-js/docs/) map. MapLibre is only the renderer; basemap tiles come from the providers below.

## Architecture

| File | Responsibility |
| --- | --- |
| `site/map.js` | The view: loading the season, search and filters, the event list, and list ↔ map selection |
| `site/map/events.js` | Event data: U.S. filter, search, upcoming/past, coordinates, grouping by location, GeoJSON |
| `site/map/view.js` | MapLibre: lazy loading, basemaps, boundary, cluster, heatmap and highlight layers, popups, camera |
| `site/map/config.js` | Provider defaults and deployment overrides |
| `site/vendor/maplibre-gl/` | The official MapLibre build and stylesheet, copied from npm (do not edit) |

`site/app.js` calls `window.loadEventMap(seasonId, loadEvents)` whenever the view opens. The library, stylesheet and basemap are requested only then. One map instance is created per page load and reused; changing basemap swaps its style and re-adds the event layers. If the map cannot start (provider unreachable, no WebGL), the event list keeps working and a **Retry** button is shown.

## Event data and coordinates

Events come from `GET /api/events?seasonId=<id>`, proxied by `site/_worker.js` to the Solar API, which reads RobotEvents. Each event's `location.latitude` and `location.longitude` are the venue coordinates in that response. The site does no geocoding and ships no sample locations.

- Only events in the United States with a SKU are shown.
- Events with missing or `(0, 0)` coordinates stay in the list, marked "No map location".
- An event counts as upcoming until the end of its last day.

> **Backend note:** the Dart sources committed here do not declare `latitude` and `longitude` on `LocationSummary`, although `bin/` and the deployed API use them. Restore those model changes before building the API from this repository.

## Markers, selection and clustering

- Events at identical coordinates form one location, labelled with its event count. Its popup lists all of them with links to `/event/<sku>`.
- Clustering uses MapLibre's GeoJSON source (`clusterRadius` 46, `clusterMaxZoom` 11). `clusterProperties` sums events, so a cluster's number is events rather than locations.
- Blue means at least one upcoming event; grey means all past.
- Clicking a cluster zooms to where it splits and lists its events. Clicking a marker lists that location's events and opens the popup.
- Choosing a list result flies to it, opens the popup and highlights the marker. Hovering or focusing a row highlights its location, even inside a cluster. **Details →** opens the event page.
- Search and filters replace the source data, so markers, clusters and list always agree. Enter selects a single result or frames all results.
- **Reset** returns to the contiguous states and clears the selection. **Density** shows an event-weighted heatmap in place of markers below zoom 8.
- Markers are drawn on a canvas, so keyboard and screen reader users reach every event through the list.

## Basemap and tile providers

| Use | Provider | Key | Terms |
| --- | --- | --- | --- |
| Light (`liberty`) and dark vector basemaps, fonts, icons | [OpenFreeMap](https://openfreemap.org/) | None | Free including commercial use, no view limit, **no SLA**, provided as is ([terms](https://openfreemap.org/tos/)) |
| Satellite imagery | [USGS The National Map](https://www.usgs.gov/programs/national-geospatial-program/national-map) `USGSImageryOnly` | None | U.S. public-domain imagery with attribution; best-effort government service, tiles up to zoom 16 |

Alternatives considered (checked November 2026; confirm current terms before switching):

| Provider | Notes |
| --- | --- |
| [MapTiler](https://www.maptiler.com/cloud/pricing/) | Free tier is non-commercial or testing, with a logo; paid from $30/month; SLA only on custom plans |
| [Stadia Maps](https://stadiamaps.com/pricing/) | Free tier is non-commercial; commercial from $20/month |
| [Protomaps](https://docs.protomaps.com/deploy/cloudflare) on Cloudflare R2 | Self-hosted, low cost, most control; you update the tiles |
| [OSM standard tiles](https://operations.osmfoundation.org/policies/tiles/) | Raster only, no SLA, usage can be withdrawn |

If the site needs guaranteed uptime, move to a contracted provider or self-hosting.

## Geographic boundaries

State and county lines are drawn from the vector basemap's `boundary` layer (OpenMapTiles schema, `admin_level` 4 and 6), so the browser downloads only visible tiles. County lines are optional and appear from zoom 8; the tiles carry them from about zoom 9. A provider using another tile schema keeps its own boundary styling and the Counties button has no effect.

The earlier map's Census-derived outlines (`us-atlas`, loaded with D3 from a CDN) and the unused `california-counties.json` have been removed. No separate Census download is needed.

## Configuration

No configuration is required. To override providers, set these Cloudflare Pages variables, which `GET /api/map-config` serves to the browser:

| Variable | Meaning |
| --- | --- |
| `MAP_STYLE_LIGHT_URL` | MapLibre style JSON URL for Light |
| `MAP_STYLE_DARK_URL` | MapLibre style JSON URL for Dark |
| `MAP_SATELLITE_TILES_URL` | Raster `{z}/{x}/{y}` tile template, or `none` to hide Satellite |
| `MAP_SATELLITE_ATTRIBUTION` | Required with a custom tile URL; HTML shown in the attribution control |
| `MAP_SATELLITE_MAXZOOM` | Highest zoom the imagery provides (default 18) |
| `MAP_API_KEY` | Substituted for `{key}` in the URLs above |

URLs must be HTTPS, and style files must reference their tiles, sprites and fonts by absolute URL.

**Any key used by a browser map is visible to visitors**, including `MAP_API_KEY`. Environment variables keep it out of the repository; also restrict it to your domains in the provider's dashboard. Never use a secret key.

Local values for `wrangler pages dev` go in `.dev.vars`, which is ignored by Git.

## Attribution and licensing

The default attribution control is disabled and replaced by a compact one that starts collapsed: the (i) button in the bottom-right corner shows the credits supplied by the basemap (OpenFreeMap, © OpenMapTiles, data from OpenStreetMap) and the imagery credit on Satellite. Do not remove it. The [OSM Foundation attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines) expect credit to be visible at first, so review them before keeping it collapsed on load. MapLibre GL JS is BSD-3-Clause; its licence is published at `site/vendor/maplibre-gl/LICENSE.txt`.

## Local development

```sh
npm install
npm run build   # refresh site/vendor/ from node_modules
npm run check   # syntax-check the site scripts
npm test        # data, configuration, worker and vendored-file tests
wrangler pages dev site --binding SOLAR_API_ORIGIN=http://127.0.0.1:8787
```

The last command needs the Dart API on port 8787 (see [deploy/README.md](../deploy/README.md)).

## Deployment

- Deploy as before: `wrangler pages deploy site --project-name solarscout --branch main`. There is no bundling step, and the vendored files are committed.
- To upgrade MapLibre, change the exact version in `package.json`, then run `npm install`, `npm run build` and `npm test`. Check the map in a browser.
- After editing files in `site/map/`, bump `version` in `site/map.js` and the `?v=` on `map.js` in `site/index.html`.
- A Content Security Policy, if added, must allow the tile hosts in `connect-src` and `img-src`, and `worker-src 'self'`.
- Visitors' browsers request tiles directly from the providers, which therefore see their IP address. Review the privacy policy accordingly.
- The browser needs WebGL2.
