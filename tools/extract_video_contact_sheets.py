from pathlib import Path

import cv2
import numpy as np


VIDEOS_ROOT = Path(r"D:\UTeM\Y3S2\BITU3973 FYP\exercises videos")
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "tmp" / "video_review"

VIDEOS = {
    1: VIDEOS_ROOT / "orthopaedic" / "half_kneel_hip_flexor_stretch.mp4",
    3: VIDEOS_ROOT / "orthopaedic" / "bridging.mp4",
    4: VIDEOS_ROOT / "orthopaedic" / "side_lying_clamshell.mp4",
    6: VIDEOS_ROOT / "orthopaedic" / "leg_raise.mp4",
    7: VIDEOS_ROOT / "orthopaedic" / "side_lying_hip_abduction.mp4",
    9: VIDEOS_ROOT / "neurological" / "step_ups.mp4",
    18: VIDEOS_ROOT / "orthopaedic" / "standing_heel_raises.mp4",
    19: VIDEOS_ROOT / "orthopaedic" / "toes_raises.mp4",
    23: VIDEOS_ROOT / "orthopaedic" / "wand_flexion.mp4",
    37: VIDEOS_ROOT / "ergonomic" / "back_curl.mp4",
    41: VIDEOS_ROOT / "ergonomic" / "wall_sits.mp4",
    42: VIDEOS_ROOT / "ergonomic" / "push_ups.mp4",
    53: VIDEOS_ROOT / "neurological" / "sit_to_stand.mp4",
    57: VIDEOS_ROOT / "sports" / "seated_knee_extension.mp4",
    59: VIDEOS_ROOT / "sports" / "sitting_external_rotation.mp4",
    61: VIDEOS_ROOT / "sports" / "Low Row Exercise.mp4",
    62: VIDEOS_ROOT / "sports" / "bicep_curls.mp4",
    66: VIDEOS_ROOT / "sports" / "Single Arm Wall Press.mp4",
    71: VIDEOS_ROOT / "cardiorespiratory" / "shoulder_press.mp4",
}


def make_contact_sheet(exercise_id: int, path: Path, samples: int = 12) -> str:
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        return f"{exercise_id}: could not open {path}"

    frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = capture.get(cv2.CAP_PROP_FPS) or 0
    duration = frame_count / fps if fps else 0
    positions = np.linspace(0, max(frame_count - 1, 0), samples, dtype=int)
    tiles = []

    for index, position in enumerate(positions):
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(position))
        ok, frame = capture.read()
        if not ok:
            continue
        height, width = frame.shape[:2]
        tile_width = 320
        tile_height = max(1, round(height * tile_width / width))
        frame = cv2.resize(frame, (tile_width, tile_height))
        timestamp = position / fps if fps else 0
        cv2.rectangle(frame, (0, 0), (tile_width, 30), (0, 0, 0), -1)
        cv2.putText(
            frame,
            f"{index + 1}: {timestamp:.1f}s",
            (8, 21),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (255, 255, 255),
            1,
            cv2.LINE_AA,
        )
        tiles.append(frame)

    capture.release()
    if not tiles:
        return f"{exercise_id}: no readable frames in {path}"

    tile_height = max(tile.shape[0] for tile in tiles)
    normalized = [
        cv2.copyMakeBorder(
            tile,
            0,
            tile_height - tile.shape[0],
            0,
            0,
            cv2.BORDER_CONSTANT,
            value=(20, 20, 20),
        )
        for tile in tiles
    ]
    rows = []
    for start in range(0, len(normalized), 4):
        row = normalized[start : start + 4]
        while len(row) < 4:
            row.append(np.zeros_like(normalized[0]))
        rows.append(cv2.hconcat(row))

    sheet = cv2.vconcat(rows)
    output = OUTPUT_DIR / f"{exercise_id}_{path.stem}_contact.jpg"
    cv2.imwrite(str(output), sheet)
    return (
        f"{exercise_id}: {path.name}, {duration:.1f}s, "
        f"{frame_count} frames, {fps:.2f} fps -> {output}"
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for exercise_id, path in VIDEOS.items():
        if not path.exists():
            print(f"{exercise_id}: missing {path}")
            continue
        print(make_contact_sheet(exercise_id, path))


if __name__ == "__main__":
    main()
