#!/usr/bin/env python3
"""Verify release APK contains navigation fix and premium brand assets."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import zipfile
from pathlib import Path

AAPT = Path("/home/ubuntu/android-sdk/build-tools/35.0.0/aapt")
APK = Path("android/app/build/outputs/apk/release/app-release.apk")

REQUIRED_STRINGS = [
    "Library summary",
    "Quick actions",
    "HomeDashboardScreen",
    "LibraryPageScreen",
    "/library/videos",
    "home_dashboard",
    "ic_launcher_foreground",
    "ic_launcher_background",
]

FORBIDDEN_STRINGS = [
    "TabBarView",
    "_DashboardTabStrip",
    "HomeNavigationState",
]

MIN_ICON_BYTES = 900  # brand mdpi icon; default Flutter icon is ~128 bytes


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    if not APK.exists():
        print(f"FAIL: APK not found at {APK}")
        return 1

    print(f"APK path: {APK}")
    print(f"APK size: {APK.stat().st_size:,} bytes")
    print(f"SHA256: {sha256(APK)}")

    badging = subprocess.check_output([str(AAPT), "dump", "badging", str(APK)], text=True)
    for line in badging.splitlines()[:3]:
        print(line)

    with zipfile.ZipFile(APK) as zf:
        names = zf.namelist()
        xml_files = [n for n in names if n.endswith(".xml") and n.startswith("res/")]
        xml_blob = b""
        for name in xml_files:
            xml_blob += zf.read(name)

        pngs = [n for n in names if n.endswith(".png") and "res/" in n]
        largest_png = max((zf.getinfo(n).file_size for n in pngs), default=0)

    raw = APK.read_bytes()
    print(f"\nLargest PNG in res/: {largest_png} bytes (brand icons expected > {MIN_ICON_BYTES})")

    ok = True
    for token in REQUIRED_STRINGS:
        in_apk = token.encode() in raw or token.encode() in xml_blob
        status = "OK" if in_apk else "MISSING"
        print(f"[{status}] {token}")
        ok = ok and in_apk

    for token in FORBIDDEN_STRINGS:
        if token.encode() in raw:
            print(f"[WARN] forbidden string present: {token}")

    if largest_png < MIN_ICON_BYTES:
        print(f"[FAIL] icon assets look like default Flutter launcher (max png {largest_png} bytes)")
        ok = False
    else:
        print("[OK] branded launcher PNGs present")

    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    print(f"\nBuilt from commit: {commit}")

    if not ok:
        return 1
    print("\nVERIFICATION PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
