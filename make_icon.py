#!/usr/bin/env python3
"""
Generates AppIcon.icns for IT Admin.app using AppKit.
Run from inside the gam-ui venv: .venv/bin/python make_icon.py <output.icns>
"""
import re
import sys
import os
import subprocess
import tempfile

# Aircall "A" mark — viewBox 0 0 83 82
AIRCALL_PATH = (
    "M41.5127 0C50.2138 1.04193e-05 57.9105 0.696391 62.5928 1.76367"
    "C71.9284 3.6985 79.2801 10.9594 81.2393 20.1797"
    "C82.3199 24.8042 83.0254 32.4062 83.0254 41"
    "C83.0254 49.5938 82.3199 57.1958 81.2393 61.8203"
    "C79.2801 71.0406 71.9284 78.3015 62.5928 80.2363"
    "C57.9105 81.3036 50.2138 82 41.5127 82"
    "C32.8117 82 25.115 81.3036 20.4326 80.2363"
    "C11.097 78.3015 3.74528 71.0406 1.78613 61.8203"
    "C0.705501 57.1958 5.21614e-08 49.5938 0 41"
    "C0 32.4062 0.705501 24.8042 1.78613 20.1797"
    "C3.74528 10.9594 11.097 3.6985 20.4326 1.76367"
    "C25.115 0.696431 32.8117 0 41.5127 0Z"
    "M41.5361 18.0869C39.2395 18.0869 37.2319 18.3305 36.1426 18.6953"
    "C35.9288 18.7684 35.7616 18.8395 35.6299 18.9141"
    "C35.2924 19.0903 34.9872 19.3189 34.7227 19.5918"
    "C33.0647 21.2116 29.3877 29.5163 25.8721 39.7744"
    "C22.7968 48.7476 20.738 56.6097 20.4844 59.9678"
    "C20.4668 60.3047 20.4668 61.4233 21.1775 62.75"
    "C23.6722 63.2769 26.233 63.7247 29.4902 64.0459"
    "C30.6365 64.1515 31.2974 63.7625 31.5732 63.125"
    "C32.3684 61.2864 34.0325 59.9035 36.0537 59.4834"
    "C37.2719 59.2049 39.2744 59.0234 41.5381 59.0234"
    "C43.8018 59.0234 45.8043 59.2049 47.0225 59.4834"
    "C49.0583 59.9065 50.7312 61.3066 51.5195 63.165"
    "C51.7797 63.7781 52.4127 64.1534 53.083 64.0928"
    "C53.5947 64.0449 56.8479 63.7237 60.8916 62.7539"
    "C61.8986 62.3784 62.6094 61.4233 62.6094 60.3047"
    "C62.3382 56.6097 60.2794 48.7476 57.2041 39.7744"
    "C53.6884 29.5163 50.0114 21.2116 48.3535 19.5918"
    "C48.0894 19.3189 47.7838 19.0903 47.4463 18.9141"
    "C47.3145 18.8395 47.1474 18.7684 46.9492 18.7012"
    "C45.8443 18.3311 43.8369 18.0869 41.5361 18.0869Z"
)
SVG_W, SVG_H = 83.0, 82.0


def parse_path(d):
    tokens = re.findall(r'[MmCcLlZz]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?', d)
    cmds, cmd, nums = [], None, []
    for t in tokens:
        if t in 'MmCcLlZz':
            if cmd is not None:
                cmds.append((cmd, nums))
            cmd, nums = t, []
        else:
            nums.append(float(t))
    if cmd is not None:
        cmds.append((cmd, nums))
    return cmds


def build_bezier(svg_d, scale, x_off, y_off):
    from AppKit import NSBezierPath
    def p(x, y):
        return (x * scale + x_off, (SVG_H - y) * scale + y_off)

    path = NSBezierPath.bezierPath()
    path.setWindingRule_(1)  # NSEvenOddWindingRule
    for cmd, nums in parse_path(svg_d):
        if cmd == 'M':
            for i in range(0, len(nums), 2):
                pt = p(nums[i], nums[i+1])
                path.moveToPoint_(pt) if i == 0 else path.lineToPoint_(pt)
        elif cmd == 'C':
            for i in range(0, len(nums), 6):
                path.curveToPoint_controlPoint1_controlPoint2_(
                    p(nums[i+4], nums[i+5]),
                    p(nums[i],   nums[i+1]),
                    p(nums[i+2], nums[i+3]),
                )
        elif cmd == 'Z':
            path.closePath()
    return path


def draw_icon(size=1024):
    from AppKit import NSImage, NSColor, NSBezierPath
    from Foundation import NSMakeSize, NSMakeRect

    img = NSImage.alloc().initWithSize_(NSMakeSize(size, size))
    img.lockFocus()

    # Dark green (#002620) rounded rect background
    NSColor.colorWithSRGBRed_green_blue_alpha_(0/255, 38/255, 32/255, 1.0).setFill()
    NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
        NSMakeRect(0, 0, size, size), size * 0.22, size * 0.22
    ).fill()

    # White Aircall A mark, scaled to 65% of icon, centred
    mark = size * 0.65
    scale = mark / max(SVG_W, SVG_H)
    x_off = (size - SVG_W * scale) / 2
    y_off = (size - SVG_H * scale) / 2
    NSColor.whiteColor().setFill()
    build_bezier(AIRCALL_PATH, scale, x_off, y_off).fill()

    img.unlockFocus()
    return img


def save_png(img, path):
    from AppKit import NSBitmapImageRep
    tiff = img.TIFFRepresentation()
    rep  = NSBitmapImageRep.imageRepWithData_(tiff)
    png  = rep.representationUsingType_properties_(4, None)  # NSPNGFileType = 4
    png.writeToFile_atomically_(path, True)


def build_icns(output_path):
    with tempfile.TemporaryDirectory() as tmp:
        master = os.path.join(tmp, "master.png")
        save_png(draw_icon(1024), master)

        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)

        sizes = [
            ("icon_16x16.png",        16),
            ("icon_16x16@2x.png",     32),
            ("icon_32x32.png",        32),
            ("icon_32x32@2x.png",     64),
            ("icon_128x128.png",     128),
            ("icon_128x128@2x.png",  256),
            ("icon_256x256.png",     256),
            ("icon_256x256@2x.png",  512),
            ("icon_512x512.png",     512),
            ("icon_512x512@2x.png", 1024),
        ]
        for name, s in sizes:
            subprocess.run(
                ["sips", "-z", str(s), str(s), master, "--out",
                 os.path.join(iconset, name)],
                check=True, capture_output=True,
            )

        subprocess.run(
            ["iconutil", "-c", "icns", iconset, "-o", output_path],
            check=True, capture_output=True,
        )
    print(f"  Icon → {output_path}")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.icns"
    build_icns(out)
