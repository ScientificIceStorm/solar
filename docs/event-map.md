# Event map

The Map view (`/#map`) shows the selected season's VEX V5 events worldwide on a [Mapbox GL JS](https://docs.mapbox.com/mapbox-gl-js/) globe.

## How it works

| File | Responsibility |
| --- | --- |
| `site/map.js` | The whole view: filters, event list, markers, clusters, camera and loading Mapbox |
| `site/app.js` | Calls `window.loadCaliforniaMap(seasonId, loadEvents)` to open the view (the name predates worldwide events) |
| `site/_worker.js` | `GET /api/map-config`, which returns the public Mapbox token |

Mapbox GL JS and its stylesheet are loaded from `api.mapbox.com` the first time the Map page opens; there is no npm dependency or build step. If the token, library or map cannot load, a message is shown and the event list keeps working. Opening the page again retries.

## Events

- Events come from `GET /api/events?seasonId=<id>`. Only events with a SKU are shown.
- The list defaults to upcoming and ongoing events. An event counts as upcoming until the day after its end date begins.
- Search matches the name, city, country or SKU.
- Events with missing or `(0, 0)` coordinates stay in the list but have no marker.
- The list shows 100 rows at a time.

## Markers and selection

- Nearby events are clustered, and a cluster shows its number of events.
- Clicking a cluster zooms to it and lists its events. Clicking a marker lists every event at that location.
- **Show all events** clears the selection without moving the map. **Reset** also returns the map to its starting view.
- On touch screens, two fingers move the map.

## Token

See [deploy/README.md](../deploy/README.md#event-map-token) for creating, restricting and setting `MAPBOX_PUBLIC_TOKEN`.

## Attribution and privacy

Map credits sit behind the (i) button. Keep that control, and review [Mapbox's attribution requirements](https://docs.mapbox.com/help/getting-started/attribution/) before changing it. Mapbox's handling of visitor data is described in `site/privacy.html`, and library credits in `site/credits.html`.

## Changing the map

- After editing `site/map.js` or `site/styles.css`, bump the `?v=` values in the HTML files that load them.
- To upgrade Mapbox GL JS, change the version in the `library` URL in `site/map.js` and in `site/credits.html`.
- Run `npm run check` to syntax-check the site scripts, and check the map in a browser.
