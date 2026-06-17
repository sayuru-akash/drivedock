#!/usr/bin/env python3
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DERIVED_DATA_DIR = ROOT_DIR / ".build" / "readme-screenshots"
ASSET_DIR = ROOT_DIR / "docs" / "assets" / "screenshots"
APP_PATH = DERIVED_DATA_DIR / "Build" / "Products" / "Debug" / "DriveDock.app"
RUN_APP_PATH = Path("/tmp/DriveDockReadmeScreenshots.app")
WINDOW_HELPER = DERIVED_DATA_DIR / "drivedock-window-id"

SCENES = [
    ("main", "main-window.png"),
    ("queue", "queue.png"),
    ("destination-picker", "destination-picker.png"),
    ("downloads", "downloads.png"),
    ("settings", "settings.png"),
    ("drive-browser", "drive-browser.png"),
    ("menu-bar", "menu-bar.png"),
]


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=ROOT_DIR, text=True, check=True, **kwargs)


def terminate_drivedock() -> None:
    subprocess.run(["killall", "DriveDock"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def build_app() -> None:
    run([
        "xcodebuild",
        "-project", "DriveDock.xcodeproj",
        "-scheme", "DriveDock",
        "-configuration", "Debug",
        "-derivedDataPath", str(DERIVED_DATA_DIR),
        "ENABLE_DEBUG_DYLIB=NO",
        "build",
    ])


def prepare_launch_bundle() -> None:
    if RUN_APP_PATH.exists():
        shutil.rmtree(RUN_APP_PATH)
    shutil.copytree(APP_PATH, RUN_APP_PATH, symlinks=True)
    subprocess.run(["xattr", "-cr", str(RUN_APP_PATH)], check=False)


def build_window_helper() -> None:
    helper_source = DERIVED_DATA_DIR / "drivedock-window-id.swift"
    helper_source.write_text(
        """
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let expectedPID = CommandLine.arguments.dropFirst().first.flatMap { Int32($0) }
for window in windows {
    guard (window[kCGWindowOwnerName as String] as? String) == "DriveDock",
          (window[kCGWindowLayer as String] as? Int) == 0,
          expectedPID == nil || (window[kCGWindowOwnerPID as String] as? Int32) == expectedPID,
          let id = window[kCGWindowNumber as String] else {
        continue
    }
    print(id)
    exit(0)
}
exit(1)
""".strip() + "\n",
        encoding="utf-8",
    )
    run(["swiftc", str(helper_source), "-o", str(WINDOW_HELPER)])


def staged_pid() -> str:
    process_pattern = "DriveDockReadmeScreenshots.app/Contents/MacOS/DriveDock"
    for _ in range(20):
        result = subprocess.run(
            ["pgrep", "-f", process_pattern],
            cwd=ROOT_DIR,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        for line in result.stdout.splitlines():
            if line.strip().isdigit():
                return line.strip()
        time.sleep(0.25)
    raise RuntimeError("Could not find staged DriveDock process")


def wait_for_window_id(pid: str) -> str:
    for _ in range(24):
        result = subprocess.run(
            [str(WINDOW_HELPER), pid],
            cwd=ROOT_DIR,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        window_id = result.stdout.strip()
        if result.returncode == 0 and window_id:
            return window_id
        time.sleep(0.5)
    raise RuntimeError("Could not find a visible DriveDock window")


def capture_scene(scene: str, file_name: str) -> None:
    output_path = ASSET_DIR / file_name
    temp_output = output_path.with_suffix(output_path.suffix + ".tmp")
    log_path = Path(f"/tmp/drivedock-screenshot-{scene}.log")

    if temp_output.exists():
        temp_output.unlink()
    if log_path.exists():
        log_path.unlink()

    terminate_drivedock()

    run([
        "open",
        "-F",
        "-n",
        str(RUN_APP_PATH),
        "--stdout", str(log_path),
        "--stderr", str(log_path),
        "--env", "DRIVEDOCK_SCREENSHOT_MODE=1",
        "--env", f"DRIVEDOCK_SCREENSHOT_SCENE={scene}",
    ])

    time.sleep(1)

    try:
        pid = staged_pid()
        window_id = wait_for_window_id(pid)
    except RuntimeError as error:
        terminate_drivedock()
        raise RuntimeError(f"{error}. Check {log_path}") from error

    run(["screencapture", "-x", "-o", "-l", window_id, str(temp_output)])
    terminate_drivedock()

    if not temp_output.exists() or temp_output.stat().st_size == 0:
        raise RuntimeError(f"Capture for scene '{scene}' did not produce an image")

    temp_output.replace(output_path)
    print(f"Captured {output_path}")


def main() -> int:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    DERIVED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    build_app()
    prepare_launch_bundle()
    build_window_helper()

    for scene, file_name in SCENES:
        capture_scene(scene, file_name)

    print(f"README screenshots are in {ASSET_DIR}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        terminate_drivedock()
        print(error, file=sys.stderr)
        raise SystemExit(1)
