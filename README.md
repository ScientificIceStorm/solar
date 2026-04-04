# solar_v6

Solar v6 is scaffolded as a Flutter app, but the current work is focused on the
API backbone first. There is no product UI yet; the main way to exercise the
code is the CLI runner in `bin/solar_api_cli.dart`.

## What Is Included

- A typed RobotEvents client with paginated requests
- A world-skills client for the public season skills endpoint
- A RoboServer client for the local OpenSkill and loader endpoints from Solar v5
- A small command runner so you can test calls from the terminal right away
- Sample OpenSkill prediction payloads and smoke tests for parsing/query building

## Config

The project intentionally does not carry over any embedded API keys from prior
Swift versions.

Configuration is resolved in this order:

1. Dart defines such as `--dart-define=ROBOEVENTS_API_KEY=...`
2. Environment variables
3. Optional `assets/config/solar.local.json` for the Flutter app
4. Optional `solar.local.json` in the project root for CLI and local tooling
5. Built-in development defaults

Supported keys:

```json
{
  "robotEventsApiKey": "your-key",
  "robotEventsBaseUrl": "https://www.robotevents.com/api/v2",
  "roboServerBaseUrl": "http://127.0.0.1:8080",
  "worldSkillsBaseUrl": "https://www.robotevents.com/api"
}
```

For the Flutter app itself, put the key in:

```json
assets/config/solar.local.json
```

Then fully restart the app so the bundled asset is reloaded.

Environment variable names:

- `ROBOEVENTS_API_KEY`
- `ROBOEVENTS_BASE_URL`
- `ROBO_SERVER_BASE_URL`
- `WORLD_SKILLS_BASE_URL`

## CLI Usage

Show commands:

```bash
dart run bin/solar_api_cli.dart --help
```

Inspect resolved config:

```bash
dart run bin/solar_api_cli.dart config
```

Fetch seasons from RobotEvents:

```bash
ROBOEVENTS_API_KEY=your-key dart run bin/solar_api_cli.dart seasons
```

Look up a team:

```bash
ROBOEVENTS_API_KEY=your-key dart run bin/solar_api_cli.dart team --number 24B
```

Fetch event teams:

```bash
ROBOEVENTS_API_KEY=your-key dart run bin/solar_api_cli.dart event-teams --event-id 12345
```

Fetch world skills:

```bash
dart run bin/solar_api_cli.dart world-skills --season 190 --grade-level "High School"
```

Check the local RoboServer:

```bash
dart run bin/solar_api_cli.dart health
```

Read the cached OpenSkill leaderboard from RoboServer:

```bash
dart run bin/solar_api_cli.dart openskill-cache --season 190 --grade-level "High School"
```

Post an OpenSkill prediction request:

```bash
dart run bin/solar_api_cli.dart openskill-predict --body-file samples/openskill_predict_request.json
```

If you test from an emulator or device, you may want to override
`ROBO_SERVER_BASE_URL` to match the host your server is reachable on.

## Validation

Run the local checks with:

```bash
flutter test
flutter analyze
```
