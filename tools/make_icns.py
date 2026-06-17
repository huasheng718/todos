#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path


ICON_TYPES = {
    "icon_16x16.png": b"icp4",
    "icon_16x16@2x.png": b"ic11",
    "icon_32x32.png": b"icp5",
    "icon_32x32@2x.png": b"ic12",
    "icon_128x128.png": b"ic07",
    "icon_128x128@2x.png": b"ic13",
    "icon_256x256.png": b"ic08",
    "icon_256x256@2x.png": b"ic14",
    "icon_512x512.png": b"ic09",
    "icon_512x512@2x.png": b"ic10",
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Build an .icns file from a standard .iconset directory.")
    parser.add_argument("iconset", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    chunks = []
    for filename, icon_type in ICON_TYPES.items():
        source = args.iconset / filename
        if not source.is_file():
            raise SystemExit(f"missing icon file: {source}")
        payload = source.read_bytes()
        chunks.append(icon_type + struct.pack(">I", len(payload) + 8) + payload)

    body = b"".join(chunks)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


if __name__ == "__main__":
    main()
