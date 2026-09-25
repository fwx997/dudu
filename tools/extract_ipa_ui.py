"""Extract UI evidence and selected image assets from the supplied 2.56.1 IPA.

Usage: python tools/extract_ipa_ui.py ../香色闺阁_2.56.1.ipa
The executable and sample books are deliberately not copied into the app.
"""

import hashlib
import io
import json
import plistlib
import struct
import sys
import zlib
from pathlib import Path
from zipfile import ZipFile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Resources/Assets.xcassets"
REFERENCE = ROOT / "docs/ipa-reference"


def png_chunks(data):
    offset = 8
    while offset < len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        yield data[offset + 4:offset + 8], data[offset + 8:offset + 8 + size]
        offset += size + 12


def paeth(a, b, c):
    p = a + b - c
    distances = (abs(p - a), abs(p - b), abs(p - c))
    return (a, b, c)[distances.index(min(distances))]


def unfilter_row(row, previous, method, channels):
    for i in range(len(row)):
        left = row[i - channels] if i >= channels else 0
        above = previous[i]
        corner = previous[i - channels] if i >= channels else 0
        predictors = (0, left, above, (left + above) // 2, paeth(left, above, corner))
        row[i] = (row[i] + predictors[method]) & 255
    return row


def decode_png(data):
    chunks = list(png_chunks(data))
    if not any(name == b"CgBI" for name, _ in chunks):
        return Image.open(io.BytesIO(data)).convert("RGBA")
    header = next(value for name, value in chunks if name == b"IHDR")
    width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", header)
    if depth != 8 or color not in (2, 6) or interlace != 0:
        raise ValueError("Unsupported Apple PNG format")
    channels = 4 if color == 6 else 3
    stride = width * channels
    raw = zlib.decompress(b"".join(v for n, v in chunks if n == b"IDAT"), -15)
    previous = bytearray(stride)
    pixels = bytearray()
    for y in range(height):
        start = y * (stride + 1)
        row = unfilter_row(bytearray(raw[start + 1:start + stride + 1]), previous, raw[start], channels)
        pixels.extend(row)
        previous = row
    for i in range(0, len(pixels), channels):
        blue, green, red = pixels[i:i + 3]
        alpha = pixels[i + 3] if channels == 4 else 255
        scale = 255 / alpha if alpha else 0
        pixels[i:i + 3] = bytes(min(255, round(c * scale)) for c in (red, green, blue))
    return Image.frombytes("RGBA" if channels == 4 else "RGB", (width, height), bytes(pixels))


def write_asset(archive, prefix, source, name):
    destination = ASSETS / (name + ".imageset")
    destination.mkdir(parents=True, exist_ok=True)
    images = []
    evidence = []
    for scale in (2, 3):
        path = prefix + source + f"@{scale}x.png"
        if path not in archive.namelist():
            continue
        raw = archive.read(path)
        filename = f"{name}@{scale}x.png"
        bitmap = decode_png(raw)
        bitmap.save(destination / filename)
        images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
        evidence.append({"path": path, "sha256": hashlib.sha256(raw).hexdigest(), "size": bitmap.size})
    (destination / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    return evidence


def main(ipa):
    REFERENCE.mkdir(parents=True, exist_ok=True)
    with ZipFile(ipa) as archive:
        info_path = next(n for n in archive.namelist() if n.count("/") == 2 and n.endswith(".app/Info.plist"))
        prefix = info_path.removesuffix("Info.plist")
        info = plistlib.loads(archive.read(info_path))
        manifest = {"version": info["CFBundleShortVersionString"], "ipa_sha256": hashlib.sha256(Path(ipa).read_bytes()).hexdigest()}
        manifest["interface_files"] = [n for n in archive.namelist() if n.endswith((".nib", ".storyboard"))]
        for path in archive.namelist():
            if path.startswith(prefix + "dir_res/plist_") and path.endswith(".plist"):
                value = plistlib.loads(archive.read(path))
                (REFERENCE / (Path(path).stem + ".json")).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        mapping = {f"xsg-shelf-{i}": f"dir_res/dir_bookshelf/icon_{i}" for i in range(5)}
        icons = ["back", "mulu", "more", "yudu", "yuyin", "zihao", "shoucang", "shuaxin", "fanye", "autoread", "yejian", "baitian"]
        mapping.update({f"xsg-reader-{name}": f"dir_res/dir_readview/{name}" for name in icons})
        mapping.update({f"xsg-paper-{i}": f"dir_res/dir_readview/theme_bg{i}" for i in [1, 3, 4, 5, 6, 7, 8]})
        manifest["assets"] = {name: write_asset(archive, prefix, source, name) for name, source in mapping.items()}
        for kind, suffix in [("text", "Text"), ("image", "Comic"), ("audio", "Audio"), ("video", "Video")]:
            source_path = next(n for n in archive.namelist() if n.endswith("/localSource" + suffix))
            path = source_path.rsplit("/", 1)[0] + "/localCover"
            name = "xsg-file-" + kind
            destination = ASSETS / (name + ".imageset")
            destination.mkdir(parents=True, exist_ok=True)
            bitmap = decode_png(archive.read(path))
            bitmap.save(destination / (name + ".png"))
            contents = {"images": [{"filename": name + ".png", "idiom": "universal", "scale": "2x"}], "info": {"author": "xcode", "version": 1}}
            (destination / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
            manifest["assets"][name] = [{"path": path, "sha256": hashlib.sha256(archive.read(path)).hexdigest(), "size": bitmap.size}]
    (REFERENCE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Extracted {len(mapping)} image sets and 9 UI configuration files; version {manifest['version']}.")


if __name__ == "__main__":
    main(sys.argv[1])
