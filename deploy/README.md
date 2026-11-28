# Publish Solar on Cloudflare Pages

Pages serves the website from `site/` and forwards its public data routes to the existing Dart API. This keeps the VEX credential and the match index on the API server.

1. Build the API image from the repository root with `docker build -f deploy/origin/Dockerfile -t solar-api .`. Run it on a host that gives it a public HTTPS URL and forwards requests to port 8787.
2. Set `ROBOEVENTS_API_KEY` and a random `SOLAR_ORIGIN_TOKEN` as secrets on the API host. Mount a writable persistent volume at `/var/cache/solar` for the service user (UID 10001). If the host requires a separate health check, use the root path.
3. Sign in with `wrangler login`. Create a project with `wrangler pages project create solarscout --production-branch main`.
4. In the Pages production settings, set `SOLAR_API_ORIGIN` to the HTTPS origin URL. Set the same `SOLAR_ORIGIN_TOKEN` as a Pages secret. Deploy from the repository root with `wrangler pages deploy site --project-name solarscout --branch main`.
5. Use the `pages.dev` URL printed by Wrangler. Verify World Skills, the event map, an event replay, and a team page. Add a custom domain from the project's **Custom domains** tab when ready.

## Event map token

The Map page uses [Mapbox GL JS](https://docs.mapbox.com/mapbox-gl-js/), which needs a Mapbox access token. The Pages worker serves it to the browser from `/api/map-config`.

1. In the [Mapbox account console](https://console.mapbox.com/account/access-tokens/), create a token for this site with only the default public scopes. It must start with `pk.`; the worker refuses anything else. Never use a secret (`sk.`) token.
2. Restrict the token to the site's URLs: `https://skyloft.tech` and the project's `pages.dev` address. Every visitor can read the token, so the URL restriction is what stops other sites from using it on your account. For local previews, use a separate token that also allows `http://localhost:8788` (or an unrestricted one that you never deploy).
3. Set `MAPBOX_PUBLIC_TOKEN` in the Pages settings (production, and preview if used), or run `wrangler pages secret put MAPBOX_PUBLIC_TOKEN --project-name solarscout`. Redeploy afterwards.
4. For local previews, put `MAPBOX_PUBLIC_TOKEN=pk.…` in `.dev.vars` at the repository root. Git ignores that file.

Without a valid token the Map page shows "The map is awaiting setup." and the event list still works. Map loads count toward the Mapbox account's usage and billing.

## Season seed

Without a persistent volume the API starts every deploy with an empty cache and re-crawls the season from RobotEvents for hours, so rankings and win probabilities would run on partial data. `deploy/seed/` (loaded through `SOLAR_SITE_SEED_DIR`) gives it the season's matches at start-up; the regular crawl adds anything newer. Rebuild it before a deploy when it is weeks old:

```sh
python deploy/build_seed.py --cache .solar_rankings_cache/companion
```

`--cache` reuses a local server's cache (run the server and open the Teams page to fill it); `--events <dir>` also accepts saved `/api/event?...&division=...` responses.

The seed also carries each finished event's match replay links (`match-videos-<event>-<division>.json`): the API can't read YouTube broadcast start times from a datacenter host without `YOUTUBE_API_KEY`, so they are worked out locally, where it can. Save the season's event list (`/api/events?seasonId=<season>` from a local server) and run:

```sh
dart run deploy/build_match_videos.dart --events events.json --state progress.json
```

It makes no RobotEvents API calls (matches come from the seed). `--state` lets an interrupted run resume. Each link starts 35 seconds before the computed moment, because broadcast and match clocks drift by up to about half a minute.

For a local Pages preview with the Dart server on port 8787, run:

```sh
wrangler pages dev site --binding SOLAR_API_ORIGIN=http://127.0.0.1:8787
```
