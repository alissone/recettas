#!/usr/bin/env python3
"""Convert a raw sleep-button log into sleep/wake events for public.sleep_events.

Usage:
    python sleep_log_to_events.py INPUT.txt --user-id USER_UUID [-o OUTPUT.csv]

The input is one ISO-8601 timestamp per line, logged whenever the button was
pressed, with no distinction between falling asleep and waking up. Events are
reconstructed with three rules:

1. Cluster: presses within CLUSTER_MINUTES of each other are one event
   (double-taps, re-logs). A cluster keeps its first and last timestamp; if it
   turns out to be a sleep event the last press is used (the final "going to
   sleep now"), if a wake event the first press (the first moment awake).
2. Pair greedily: consecutive clusters (A, B) become a sleep/wake pair when
   the interval looks like either
     - night sleep: A starts between NIGHT_START (19:00) and NIGHT_END (04:00)
       and lasts MIN_SLEEP_MIN..MAX_NIGHT_HOURS, or
     - nap: A starts during the day and lasts MIN_SLEEP_MIN..MAX_NAP_HOURS.
3. Discard: a cluster that cannot open a valid pair with its successor is an
   outlier (stray press, or a sleep/wake whose counterpart was never logged).
   Discards are written to a companion *_discarded.csv for inspection.

Interrupted nights come out naturally as two sleep/wake pairs.
"""
import argparse
import csv
import sys
from datetime import datetime, timedelta
from pathlib import Path

CLUSTER_MINUTES = 15      # presses closer than this are the same event
MIN_SLEEP_MIN = 20        # shortest believable sleep segment (night or nap)
MAX_NIGHT_HOURS = 16      # longer than this means the wake press is missing
MAX_NAP_HOURS = 3         # longest believable daytime nap
NIGHT_START = 19          # night sleep may start from this hour...
NIGHT_END = 4             # ...until (exclusive) this hour


def parse_log(path: Path):
    stamps = []
    for lineno, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            stamps.append(datetime.fromisoformat(line))
        except ValueError:
            print(f"line {lineno}: unparseable timestamp {line!r}, skipping",
                  file=sys.stderr)
    stamps.sort()
    return stamps


def cluster(stamps):
    """Merge chains of presses separated by < CLUSTER_MINUTES into (first, last)."""
    gap = timedelta(minutes=CLUSTER_MINUTES)
    clusters = []
    for ts in stamps:
        if clusters and ts - clusters[-1][1] <= gap:
            clusters[-1][1] = ts
        else:
            clusters.append([ts, ts])
    return clusters


def in_night_window(ts):
    return ts.hour >= NIGHT_START or ts.hour < NIGHT_END


def classify(sleep_at, wake_at):
    """Return 'night', 'nap', or None for the interval sleep_at..wake_at."""
    duration = wake_at - sleep_at
    if duration < timedelta(minutes=MIN_SLEEP_MIN):
        return None
    if in_night_window(sleep_at):
        return 'night' if duration <= timedelta(hours=MAX_NIGHT_HOURS) else None
    return 'nap' if duration <= timedelta(hours=MAX_NAP_HOURS) else None


def pair(clusters):
    """Greedy pairing of clusters into (sleep_at, wake_at, kind) intervals."""
    pairs = []
    discarded = []
    i = 0
    while i < len(clusters):
        if i + 1 == len(clusters):
            discarded.append((clusters[i][0], 'no following event to pair with'))
            break
        sleep_at = clusters[i][1]       # last press of the falling-asleep cluster
        wake_at = clusters[i + 1][0]    # first press of the waking-up cluster
        kind = classify(sleep_at, wake_at)
        if kind:
            pairs.append((sleep_at, wake_at, kind))
            i += 2
        else:
            hours = (wake_at - sleep_at).total_seconds() / 3600
            discarded.append(
                (sleep_at, f'next event {hours:.1f}h later does not fit a '
                           f'{"night sleep" if in_night_window(sleep_at) else "nap"}'))
            i += 1
    return pairs, discarded


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('log_path', type=Path)
    parser.add_argument('--user-id', required=True,
                        help='UUID of the profiles row to own these events')
    parser.add_argument('-o', '--output', type=Path, default=None)
    args = parser.parse_args()

    output = args.output or args.log_path.with_name(args.log_path.stem + '_events.csv')
    discarded_path = output.with_name(output.stem.replace('_events', '') + '_discarded.csv')

    stamps = parse_log(args.log_path)
    if not stamps:
        print('No timestamps found.', file=sys.stderr)
        sys.exit(1)

    clusters = cluster(stamps)
    pairs, discarded = pair(clusters)

    with output.open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['user_id', 'event_type', 'occurred_at'])
        for sleep_at, wake_at, _kind in pairs:
            writer.writerow([args.user_id, 'sleep', sleep_at.isoformat()])
            writer.writerow([args.user_id, 'wake', wake_at.isoformat()])

    with discarded_path.open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['occurred_at', 'reason'])
        for ts, reason in discarded:
            writer.writerow([ts.isoformat(), reason])

    nights = sum(1 for p in pairs if p[2] == 'night')
    naps = len(pairs) - nights
    night_avg = (sum(((w - s).total_seconds() for s, w, k in pairs if k == 'night'), 0.0)
                 / nights / 3600) if nights else 0.0
    print(f"{len(stamps)} presses -> {len(clusters)} events after clustering.")
    print(f"Paired {nights} night sleeps (avg {night_avg:.1f}h) and {naps} naps "
          f"-> {2 * len(pairs)} rows in {output}.")
    print(f"Discarded {len(discarded)} unpairable events -> {discarded_path}.")


if __name__ == '__main__':
    main()
