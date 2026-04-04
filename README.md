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
3. Optional `solar.local.json` in the project root
4. Built-in development defaults

Supported keys:

```json
{
  "robotEventsApiKey": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzIiwianRpIjoiMzNkMTc3MWU2YzU3MGUzNWMzMzlkYmQxNTU4MTA3NGFiNzRlMmIwOGQ3Y2E5OGJmMjM4Y2NjZDQ5M2E2ZjcxNGQwZTIxNjdjZGIyM2I0OTUiLCJpYXQiOjE3NjczNzg2NjguOTU2MTkwMSwibmJmIjoxNzY3Mzc4NjY4Ljk1NjE5MTEsImV4cCI6MjcxNDA2MzQ2OC45NTAzNDQxLCJzdWIiOiIxNTAxNjciLCJzY29wZXMiOltdfQ.KdxeT2svi9XmouJ1QQiRbf9cEmmbaL04iGahh79P9cZM4xeUMvQi7veD4ypPWGX5Ay_qt0sPS1Aup83emLZ4-se09Prt7ua4IyKdHfOeFhbfJUrzJoSX09CJDpdAD2Q_HC8AILgkiRWJ7rB-nNHEgbWspbONHgoKw-3hBWl8ylm2NizK4dkAJ0GnGMLCxpAEWTlA4QTx-tEVgmNVz5TopZa-aYIjh-ZjpDoh3LkUT8qi-5ytGRRi_YRk2HhHh_gDWjcQtodYvb6pBbyhnj8hWLdE8LDMlngh7kWNMEVpF0oCj7BrVya6uLSnccq8Lr5JrHwI0NLEphiAuzKXIIb8Wk9_1WalowwHGqesvlJjsQJFk8j2wGiBD3CaNW1LyxlQGlx8ROkOqH5lZ2XhsXKMZ1qqyCZxQ-_Tg5bMmYRZlEJTro6OiMJlqbJykhCMUQcOzXqfPkDurQikqiaImk3z8EkWNP10Zi86JDTH3nlax7lmM4_BsI-UJz1OFaak3XlI-_U0eucc8JWtNFh8Rogsnf6XNlFNCHNfOaJxTO_-TL23tm9WzcQbStQeeawlvZyr8rYVZh7QMloKf1HvhVzBX5lnrUZGxEWvVTRhWSHucSnY3jQAqWd_Fkjwc2aAOaSU2TrpWraMvsXh315mC33YXIihK4qhjKAz7iFcqY0zbQw",
  "robotEventsBaseUrl": "https://www.robotevents.com/api/v2",
  "roboServerBaseUrl": "http://127.0.0.1:8080",
  "worldSkillsBaseUrl": "https://www.robotevents.com/api"
}
```

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
ROBOEVENTS_API_KEY=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzIiwianRpIjoiMzNkMTc3MWU2YzU3MGUzNWMzMzlkYmQxNTU4MTA3NGFiNzRlMmIwOGQ3Y2E5OGJmMjM4Y2NjZDQ5M2E2ZjcxNGQwZTIxNjdjZGIyM2I0OTUiLCJpYXQiOjE3NjczNzg2NjguOTU2MTkwMSwibmJmIjoxNzY3Mzc4NjY4Ljk1NjE5MTEsImV4cCI6MjcxNDA2MzQ2OC45NTAzNDQxLCJzdWIiOiIxNTAxNjciLCJzY29wZXMiOltdfQ.KdxeT2svi9XmouJ1QQiRbf9cEmmbaL04iGahh79P9cZM4xeUMvQi7veD4ypPWGX5Ay_qt0sPS1Aup83emLZ4-se09Prt7ua4IyKdHfOeFhbfJUrzJoSX09CJDpdAD2Q_HC8AILgkiRWJ7rB-nNHEgbWspbONHgoKw-3hBWl8ylm2NizK4dkAJ0GnGMLCxpAEWTlA4QTx-tEVgmNVz5TopZa-aYIjh-ZjpDoh3LkUT8qi-5ytGRRi_YRk2HhHh_gDWjcQtodYvb6pBbyhnj8hWLdE8LDMlngh7kWNMEVpF0oCj7BrVya6uLSnccq8Lr5JrHwI0NLEphiAuzKXIIb8Wk9_1WalowwHGqesvlJjsQJFk8j2wGiBD3CaNW1LyxlQGlx8ROkOqH5lZ2XhsXKMZ1qqyCZxQ-_Tg5bMmYRZlEJTro6OiMJlqbJykhCMUQcOzXqfPkDurQikqiaImk3z8EkWNP10Zi86JDTH3nlax7lmM4_BsI-UJz1OFaak3XlI-_U0eucc8JWtNFh8Rogsnf6XNlFNCHNfOaJxTO_-TL23tm9WzcQbStQeeawlvZyr8rYVZh7QMloKf1HvhVzBX5lnrUZGxEWvVTRhWSHucSnY3jQAqWd_Fkjwc2aAOaSU2TrpWraMvsXh315mC33YXIihK4qhjKAz7iFcqY0zbQw dart run bin/solar_api_cli.dart seasons
```

Look up a team:

```bash
ROBOEVENTS_API_KEY=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzIiwianRpIjoiMzNkMTc3MWU2YzU3MGUzNWMzMzlkYmQxNTU4MTA3NGFiNzRlMmIwOGQ3Y2E5OGJmMjM4Y2NjZDQ5M2E2ZjcxNGQwZTIxNjdjZGIyM2I0OTUiLCJpYXQiOjE3NjczNzg2NjguOTU2MTkwMSwibmJmIjoxNzY3Mzc4NjY4Ljk1NjE5MTEsImV4cCI6MjcxNDA2MzQ2OC45NTAzNDQxLCJzdWIiOiIxNTAxNjciLCJzY29wZXMiOltdfQ.KdxeT2svi9XmouJ1QQiRbf9cEmmbaL04iGahh79P9cZM4xeUMvQi7veD4ypPWGX5Ay_qt0sPS1Aup83emLZ4-se09Prt7ua4IyKdHfOeFhbfJUrzJoSX09CJDpdAD2Q_HC8AILgkiRWJ7rB-nNHEgbWspbONHgoKw-3hBWl8ylm2NizK4dkAJ0GnGMLCxpAEWTlA4QTx-tEVgmNVz5TopZa-aYIjh-ZjpDoh3LkUT8qi-5ytGRRi_YRk2HhHh_gDWjcQtodYvb6pBbyhnj8hWLdE8LDMlngh7kWNMEVpF0oCj7BrVya6uLSnccq8Lr5JrHwI0NLEphiAuzKXIIb8Wk9_1WalowwHGqesvlJjsQJFk8j2wGiBD3CaNW1LyxlQGlx8ROkOqH5lZ2XhsXKMZ1qqyCZxQ-_Tg5bMmYRZlEJTro6OiMJlqbJykhCMUQcOzXqfPkDurQikqiaImk3z8EkWNP10Zi86JDTH3nlax7lmM4_BsI-UJz1OFaak3XlI-_U0eucc8JWtNFh8Rogsnf6XNlFNCHNfOaJxTO_-TL23tm9WzcQbStQeeawlvZyr8rYVZh7QMloKf1HvhVzBX5lnrUZGxEWvVTRhWSHucSnY3jQAqWd_Fkjwc2aAOaSU2TrpWraMvsXh315mC33YXIihK4qhjKAz7iFcqY0zbQw dart run bin/solar_api_cli.dart team --number 24B
```

Fetch event teams:

```bash
ROBOEVENTS_API_KEY=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzIiwianRpIjoiMzNkMTc3MWU2YzU3MGUzNWMzMzlkYmQxNTU4MTA3NGFiNzRlMmIwOGQ3Y2E5OGJmMjM4Y2NjZDQ5M2E2ZjcxNGQwZTIxNjdjZGIyM2I0OTUiLCJpYXQiOjE3NjczNzg2NjguOTU2MTkwMSwibmJmIjoxNzY3Mzc4NjY4Ljk1NjE5MTEsImV4cCI6MjcxNDA2MzQ2OC45NTAzNDQxLCJzdWIiOiIxNTAxNjciLCJzY29wZXMiOltdfQ.KdxeT2svi9XmouJ1QQiRbf9cEmmbaL04iGahh79P9cZM4xeUMvQi7veD4ypPWGX5Ay_qt0sPS1Aup83emLZ4-se09Prt7ua4IyKdHfOeFhbfJUrzJoSX09CJDpdAD2Q_HC8AILgkiRWJ7rB-nNHEgbWspbONHgoKw-3hBWl8ylm2NizK4dkAJ0GnGMLCxpAEWTlA4QTx-tEVgmNVz5TopZa-aYIjh-ZjpDoh3LkUT8qi-5ytGRRi_YRk2HhHh_gDWjcQtodYvb6pBbyhnj8hWLdE8LDMlngh7kWNMEVpF0oCj7BrVya6uLSnccq8Lr5JrHwI0NLEphiAuzKXIIb8Wk9_1WalowwHGqesvlJjsQJFk8j2wGiBD3CaNW1LyxlQGlx8ROkOqH5lZ2XhsXKMZ1qqyCZxQ-_Tg5bMmYRZlEJTro6OiMJlqbJykhCMUQcOzXqfPkDurQikqiaImk3z8EkWNP10Zi86JDTH3nlax7lmM4_BsI-UJz1OFaak3XlI-_U0eucc8JWtNFh8Rogsnf6XNlFNCHNfOaJxTO_-TL23tm9WzcQbStQeeawlvZyr8rYVZh7QMloKf1HvhVzBX5lnrUZGxEWvVTRhWSHucSnY3jQAqWd_Fkjwc2aAOaSU2TrpWraMvsXh315mC33YXIihK4qhjKAz7iFcqY0zbQw dart run bin/solar_api_cli.dart event-teams --event-id 12345
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
