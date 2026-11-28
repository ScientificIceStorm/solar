"""Draw local robot detections on a short section of a match video."""

import argparse
import csv
from pathlib import Path

import cv2
import numpy as np
from rfdetr import RFDETRLarge


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path)
    parser.add_argument("--start", type=float, default=0, help="Start time in seconds")
    parser.add_argument("--seconds", type=float, default=25)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--output", type=Path, help="Path for the annotated MP4")
    parser.add_argument("--track", action="store_true", help="Assign IDs across frames.")
    parser.add_argument("--field", nargs=8, type=float, metavar="COORD", help=(
        "Normalized x y coordinates of the floor corners, clockwise from top left."
    ))
    parser.add_argument("--field-until", type=float, default=float("inf"))
    parser.add_argument("--reset-at", type=float, help="Restart tracking and apply team IDs at this replay time.")
    parser.add_argument("--lost-seconds", type=float, default=1.0)
    parser.add_argument("--relink", action="append", nargs=3, default=[],
                        metavar=("SECONDS", "ID", "TEAM"))
    parser.add_argument("--actions", type=Path, help="Reviewed action and score CSV.")
    parser.add_argument("--teams", nargs="*", default=[], metavar="ID=TEAM")
    parser.add_argument("--swap", action="append", nargs=3, default=[],
                        metavar=("SECONDS", "TEAM_A", "TEAM_B"))
    args = parser.parse_args()
    if not 0 < args.lost_seconds <= 10:
        parser.error("Lost-track duration must be between 0 and 10 seconds.")
    relinks = []
    for timestamp, track_id, team in args.relink:
        try:
            seconds = float(timestamp)
            identifier = int(track_id)
        except ValueError:
            parser.error("Relink requires a time in seconds and an integer track ID.")
        if not 0 <= seconds < float("inf") or identifier < 0 or not team:
            parser.error("Invalid relink.")
        relinks.append((seconds, identifier, team.upper()))
    relinks.sort(key=lambda entry: entry[0])
    next_relink = 0
    actions = []
    if args.actions:
        with args.actions.open(encoding="utf-8-sig", newline="") as file:
            reader = csv.DictReader(file)
            if not {"seconds", "team", "action", "red", "blue"}.issubset(reader.fieldnames or []):
                parser.error("Actions CSV needs seconds,team,action,red,blue columns.")
            for row in reader:
                try:
                    seconds = float(row["seconds"])
                    scores = tuple(int(row[key]) if row[key].strip() else None for key in ("red", "blue"))
                except (ValueError, AttributeError):
                    parser.error(f"Invalid time or score on CSV line {reader.line_num}.")
                if not 0 <= seconds < float("inf") or any(s is not None and s < 0 for s in scores):
                    parser.error(f"Invalid time or score on CSV line {reader.line_num}.")
                actions.append((seconds, row["team"].strip(), row["action"].strip(), scores))
        actions.sort(key=lambda entry: entry[0])
    next_action = 0
    recent_actions = []
    red_score = blue_score = None
    if args.field and not all(0 <= value <= 1 for value in args.field):
        parser.error("Field coordinates must be between 0 and 1.")
    teams = {}
    for assignment in args.teams:
        track_id, separator, team = assignment.partition("=")
        if not separator or not track_id.isdecimal() or not team:
            parser.error("Team assignments must look like 1=3946E.")
        teams[int(track_id)] = team.upper()
    swaps = []
    for timestamp, first, second in args.swap:
        try:
            seconds = float(timestamp)
        except ValueError:
            parser.error("Swap time must be in seconds.")
        first, second = first.upper(), second.upper()
        if not 0 <= seconds < float("inf") or first == second or not {first, second}.issubset(teams.values()):
            parser.error("Each swap needs a valid time and two different teams listed in --teams.")
        swaps.append((seconds, first, second))
    swaps.sort(key=lambda swap: swap[0])
    next_swap = 0
    if args.start < 0 or args.seconds <= 0:
        parser.error("Start must be nonnegative and duration must be positive.")
    runs = Path(__file__).resolve().parents[1] / ".solar_rankings_cache/vision/runs"
    checkpoints = sorted(runs.glob("large-*/checkpoint_best_total.pth"))
    if args.checkpoint is None and not checkpoints:
        parser.error("No trained checkpoint found. Pass --checkpoint.")
    checkpoint = args.checkpoint or checkpoints[-1]
    output = args.output or args.video.with_name(f"{args.video.stem}-robots-{args.start:g}s.mp4")
    if output.exists():
        parser.error(f"Output already exists: {output}")

    source = cv2.VideoCapture(str(args.video))
    writer = None
    try:
        fps = source.get(cv2.CAP_PROP_FPS)
        if not source.isOpened() or fps <= 0:
            parser.error("Could not read the input video.")
        source.set(cv2.CAP_PROP_POS_FRAMES, round(args.start * fps))
        tracker = None
        positions = {}
        if args.track or teams:
            from trackers import ByteTrackTracker

            tracker = ByteTrackTracker(frame_rate=fps, lost_track_buffer=round(args.lost_seconds * 30))
        model = RFDETRLarge(pretrain_weights=str(checkpoint), num_classes=1, device="cuda")
        for frame_index in range(max(1, round(args.seconds * fps))):
            ok, frame = source.read()
            if not ok:
                break
            if writer is None:
                height, width = frame.shape[:2]
                projection = None
                if args.field:
                    corners = np.array(args.field, np.float32).reshape(4, 2)
                    corners *= (width, height)
                    if not cv2.isContourConvex(corners) or cv2.contourArea(corners) < 1:
                        parser.error("Field corners must form a convex quadrilateral.")
                    size = max(100, height // 3)
                    projection = cv2.getPerspectiveTransform(
                        corners, np.float32([[0, 0], [size, 0], [size, size], [0, size]])
                    )
                writer = cv2.VideoWriter(str(output), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height))
                if not writer.isOpened():
                    raise RuntimeError(f"Could not create {output}")
            replay_time = frame_index / fps
            if replay_time >= args.field_until:
                writer.write(frame)
                continue
            if tracker is not None and args.reset_at is not None and frame_index == round(args.reset_at * fps):
                tracker = ByteTrackTracker(frame_rate=fps, lost_track_buffer=round(args.lost_seconds * 30))
                positions.clear()
            detections = model.predict(
                cv2.cvtColor(frame, cv2.COLOR_BGR2RGB), threshold=0.1 if tracker else 0.5
            )
            if tracker is not None:
                detections = tracker.update(detections)
            while next_swap < len(swaps) and frame_index / fps >= swaps[next_swap][0]:
                _, first, second = swaps[next_swap]
                replacements = {first: second, second: first}
                teams = {track_id: replacements.get(team, team) for track_id, team in teams.items()}
                next_swap += 1
            while next_relink < len(relinks) and replay_time >= relinks[next_relink][0]:
                _, identifier, team = relinks[next_relink]
                teams = {track_id: name for track_id, name in teams.items() if name != team}
                teams[identifier] = team
                next_relink += 1
            if projection is not None:
                panel = np.full((size + 40, size + 28, 3), (32, 24, 18), dtype=np.uint8)
                cv2.putText(panel, "FIELD VIEW", (14, 21), cv2.FONT_HERSHEY_SIMPLEX,
                            0.55, (240, 240, 240), 1, cv2.LINE_AA)
                for step in range(7):
                    offset = round(size * step / 6)
                    cv2.line(panel, (14 + offset, 30), (14 + offset, 30 + size), (85, 78, 70), 1)
                    cv2.line(panel, (14, 30 + offset), (14 + size, 30 + offset), (85, 78, 70), 1)
                markers = []
                # Fixed Override pieces, oriented to the broadcast camera.
                cv2.polylines(panel, [np.int32([
                    (14 + size // 2, 30 + size // 3),
                    (14 + 2 * size // 3, 30 + size // 2),
                    (14 + size // 2, 30 + 2 * size // 3),
                    (14 + size // 3, 30 + size // 2),
                ])], True, (180, 180, 180), 1, cv2.LINE_AA)
                for gx, gy in ((.28,.28),(.72,.28),(.28,.72),(.72,.72),(.5,.5)):
                    cv2.circle(panel, (14 + round(gx * size), 30 + round(gy * size)),
                               4, (155, 155, 155), 1, cv2.LINE_AA)
                for gx, gy in ((.15,.15),(.85,.85),(.85,.15),(.15,.85),(.5,0),(.5,1),(0,.5),(1,.5)):
                    cv2.circle(panel, (14 + round(gx * size), 30 + round(gy * size)),
                               3, (120, 155, 210), -1, cv2.LINE_AA)
            for index, (box, score) in enumerate(zip(detections.xyxy, detections.confidence)):
                x1, y1, x2, y2 = map(int, box)
                if projection is not None:
                    point = np.float32([[[(x1 + x2) / 2, y2]]])
                    px, py = cv2.perspectiveTransform(point, projection)[0, 0]
                    margin = size * 0.06
                    if not (-margin <= px <= size + margin and -margin <= py <= size + margin):
                        continue
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                label = f"robot {score:.2f}"
                track_id = -1
                if detections.tracker_id is not None:
                    track_id = int(detections.tracker_id[index])
                    named = args.reset_at is None or replay_time >= args.reset_at
                    label = teams.get(track_id, f"ID {track_id}") if named else f"ID {track_id}"
                    if track_id < 0:
                        label = "Unknown"
                if projection is not None:
                    if track_id < 0:
                        continue
                    previous = positions.get(track_id)
                    if previous and replay_time - previous[2] <= 0.4:
                        alpha = 1 - np.exp(-(replay_time - previous[2]) / 0.15)
                        px = previous[0] + alpha * (px - previous[0])
                        py = previous[1] + alpha * (py - previous[1])
                    positions[track_id] = (px, py, replay_time)
                    markers.append((round(np.clip(px, 0, size)) + 14,
                                    round(np.clip(py, 0, size)) + 30, label))
                cv2.putText(frame, label, (x1, max(16, y1 - 4)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
            if projection is not None:
                for px, py, label in markers:
                    cv2.circle(panel, (px, py), 5, (110, 235, 175), -1, cv2.LINE_AA)
                    tx = min(px + 7, panel.shape[1] - 72)
                    cv2.putText(panel, label, (tx, max(36, py - 5)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (245, 245, 245), 1, cv2.LINE_AA)
                ph, pw = panel.shape[:2]
                frame[height // 10:height // 10 + ph, 12:12 + pw] = panel
            if args.actions:
                while next_action < len(actions) and replay_time >= actions[next_action][0]:
                    seconds, team, action, (red, blue) = actions[next_action]
                    if red is not None:
                        red_score = red
                    if blue is not None:
                        blue_score = blue
                    recent_actions.append(f"{int(seconds) // 60}:{seconds % 60:04.1f}  {team}  {action}")
                    next_action += 1
                red_text = "-" if red_score is None else str(red_score)
                blue_text = "-" if blue_score is None else str(blue_score)
                x, y = 12, height - 100
                cv2.rectangle(frame, (x, y), (min(x + 440, width - 1), height - 8), (32, 24, 18), -1)
                lines = [f"EST. SCORE   RED {red_text}   BLUE {blue_text}"]
                lines.extend(recent_actions[-2:] or ["No reviewed actions yet"])
                for line_index, line in enumerate(lines):
                    cv2.putText(frame, line, (x + 8, y + 22 + line_index * 24),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (245, 245, 245), 1, cv2.LINE_AA)
            writer.write(frame)
        if writer is None:
            parser.error("No frames at that start time.")
    finally:
        source.release()
        if writer is not None:
            writer.release()
    print(f"Saved {output.resolve()}")


if __name__ == "__main__":
    main()
