"""Export VexVision's reviewed goal and toggle examples for the browser scorer."""

import argparse
import base64
import hashlib
import json
from pathlib import Path
import sys


def browser_signature(image, crop, np):
    """Sample the original HSV feature bins on the browser's 14-by-24 grid."""
    left, top, right, bottom = crop
    cols, rows = 14, 24
    result = np.zeros((rows, cols, 4), dtype=np.float32)
    for dy in (.25, .75):
        for dx in (.25, .75):
            xs = np.floor(left + (np.arange(cols) + dx) / cols * (right-left) + .5).astype(int)
            ys = np.floor(top + (np.arange(rows) + dy) / rows * (bottom-top) + .5).astype(int)
            b, g, r = np.moveaxis(image[ys[:, None], xs].astype(np.float32), -1, 0)
            v = np.maximum(np.maximum(r, g), b)
            delta = v - np.minimum(np.minimum(r, g), b)
            safe = np.where(delta > 0, delta, 1)
            hue = np.mod(30 * np.where(v == r, (g-b)/safe, np.where(v == g, 2+(b-r)/safe, 4+(r-g)/safe)), 180)
            saturation = 255 * delta / np.maximum(v, 1)
            strength = ((v > 85) * np.clip((saturation-65)/90, 0, 1)) * 63.75
            result[:, :, 0] += strength * ((hue <= 9) | (hue >= 170))
            result[:, :, 1] += strength * ((hue >= 88) & (hue <= 128))
            result[:, :, 2] += strength * ((hue >= 18) & (hue <= 43))
            result[:, :, 3] += (.299*r + .587*g + .114*b) / 4
    return np.rint(result).astype(np.uint8)


def export(vexvision, output):
    sys.path.insert(0, str(vexvision))
    import cv2
    import numpy as np
    from tools.auto_label_goals import checked_counts, read_labels
    from tools.event_data import EVENTS, ROOT, goal_projection, load_config
    from tools.review_toggles import FACES

    models = []
    for name, event in EVENTS.items():
        settings = load_config(name)
        source = ROOT / settings["video"]
        width, height = settings["size"]
        projection, _ = goal_projection(name, settings)
        corners = np.float32([[0, 0], [144, 0], [144, 144], [0, 144]])
        corners = (cv2.perspectiveTransform(corners[None], np.linalg.inv(projection))[0] /
                   np.float32([width, height])).tolist()
        capture = cv2.VideoCapture(str(source))
        if not capture.isOpened():
            raise ValueError(f"Missing original video {source}")
        labels = {key: checked_counts(row) for key, row in read_labels(ROOT / event["out_dir"]).items()}
        if event["reviewed"]:
            reviewed = json.loads((ROOT / event["reviewed"]).read_text())
            for goal, history in reviewed["goals"].items():
                labels[goal, settings["first_frame"]] = history["initial"]
                for change in history.get("changes", []):
                    frame = change["window"][1] + 12
                    if frame <= settings["driver_end"]:
                        labels[goal, frame] = change["state"]

        references = {goal["id"]: [] for goal in settings["goals"]}
        for (goal_id, frame_index), counts in sorted(labels.items(), key=lambda item: item[0][1]):
            if counts is None or any(a <= frame_index <= b for a, b in settings["excluded_frame_ranges"]):
                continue
            capture.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
            ok, image = capture.read()
            if ok:
                goal = next(goal for goal in settings["goals"] if goal["id"] == goal_id)
                data = browser_signature(image, goal["crop"], np)
                references[goal_id].append([list(counts), base64.b64encode(data).decode("ascii")])
        capture.release()
        model = {
            "id": name,
            "name": event["title"],
            "size": settings["size"],
            "corners": corners,
            "goals": settings["goals"],
            "references": references,
            "columns": settings.get("stack_columns", {}),
            "toggleFaces": settings.get("toggle_faces", FACES),
            "insideFaces": settings.get("toggle_inside_faces", {}),
            "visibleFaces": settings.get("toggle_visibility_faces", {}),
            "yellowEdges": settings.get("toggle_yellow_edge_faces", {}),
            "unreadableGoals": event["exclude_from_fit"],
            "recording": {
                "bytes": source.stat().st_size,
                "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "path": f"/scoutvision/{event['out_dir'].split('/')[-1]}/{event['html']}",
            },
        }
        models.append(model)

    with np.load(ROOT / "out/highlander-toggles/reviewed-model/toggle-knn.npz") as saved:
        toggles = {"features": saved["features"].tolist(), "labels": saved["labels"].tolist()}
    output.write_text(json.dumps({"cameras": models, "toggles": toggles}, separators=(",", ":")), encoding="utf-8")
    for camera in models:
        print(camera["name"], sum(map(len, camera["references"].values())), "scoring examples")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vexvision", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    export(args.vexvision, args.output)
