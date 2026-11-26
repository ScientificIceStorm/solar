"""Builds deploy/seed: a starting copy of the season's matches for the API server.

The server keeps its season index in a cache folder that is empty after every
deploy (Railway has no persistent disk here), so without a seed it re-crawls
RobotEvents for hours and the rankings and odds run on partial data meanwhile.
The Dockerfile points SOLAR_SITE_SEED_DIR at deploy/seed; the server loads
these files at start-up and the regular crawl adds anything newer.

Sources (either or both):
  --cache   a server cache folder (e.g. .solar_rankings_cache/companion), whose
            rated-matches-, rating-signals- and rating-awards- files are reused
  --events  a folder of /api/event?...&division=... responses

For each division the copy with more matches wins (complete responses before
partial ones). Only the fields the server reads are kept.

  python deploy/build_seed.py --cache .solar_rankings_cache/companion --events <dir>
"""
import argparse
import glob
import json
import os
import re
import shutil

MATCH_KEYS = ('id', 'event', 'division', 'field', 'scheduled', 'started', 'round',
              'roundCode', 'instance', 'matchNumber', 'name')


def compact(match):
    row = {key: match[key] for key in MATCH_KEYS if key in match}
    row['alliances'] = [
        {
            'color': side.get('color'),
            'score': side.get('score'),
            'teams': [{'id': t.get('id'), 'number': t.get('number'), 'name': t.get('name')}
                      for t in side.get('teams') or []],
            **({'disqualifiedTeamIds': side['disqualifiedTeamIds']}
               if side.get('disqualifiedTeamIds') else {}),
        }
        for side in match.get('alliances') or []
    ]
    return row


def load(path):
    try:
        with open(path, encoding='utf-8') as file:
            return json.load(file)
    except (OSError, ValueError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--cache')
    parser.add_argument('--events')
    parser.add_argument('--out', default=os.path.join(os.path.dirname(__file__), 'seed'))
    args = parser.parse_args()

    best = {}  # (event, division) -> (complete, count, matches)

    def offer(key, matches, complete):
        matches = [m for m in matches or [] if isinstance(m, dict) and m.get('alliances')]
        if not matches:
            return
        candidate = (complete, len(matches), matches)
        if key not in best or candidate[:2] > best[key][:2]:
            best[key] = candidate

    if args.cache:
        for path in glob.glob(os.path.join(args.cache, 'rated-matches-*.json')):
            found = re.search(r'rated-matches-(\d+)-(\d+)\.json$', path)
            data = load(path)
            if found and data:
                offer((int(found[1]), int(found[2])), data.get('matches'), True)
    if args.events:
        for path in glob.glob(os.path.join(args.events, '*.json')):
            data = load(path)
            if not data or not data.get('event') or not data.get('division'):
                continue
            offer((data['event']['id'], data['division']['id']), data.get('matches'),
                  not data.get('partial'))

    if os.path.isdir(args.out):
        shutil.rmtree(args.out)
    os.makedirs(args.out)
    total = 0
    for (event, division), (_, count, matches) in sorted(best.items()):
        with open(os.path.join(args.out, f'rated-matches-{event}-{division}.json'), 'w',
                  encoding='utf-8') as file:
            json.dump({'matches': [compact(m) for m in matches]}, file, separators=(',', ':'))
        total += count
    copied = 0
    if args.cache:
        for pattern in ('rating-signals-*.json', 'rating-awards-*.json'):
            for path in glob.glob(os.path.join(args.cache, pattern)):
                if load(path) is not None:
                    shutil.copy(path, args.out)
                    copied += 1
    print(f'{len(best)} divisions, {total} matches, {copied} signal/award files -> {args.out}')


if __name__ == '__main__':
    main()
