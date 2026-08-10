#!/bin/bash
# Regenerates img/AppIcon.icns from img/logo.svg. Dev-time tool: the .icns is
# checked in, so scripts/make-app.sh and CI never need an SVG rasterizer.
# Uses only system tools: swiftc (NSImage renders SVG natively on macOS 13+),
# sips to downscale, iconutil to pack.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Render the full icon canvas. logo.svg is already a complete 1024pt icon:
# the rounded-box gradient background plus the lime at 85% of the box width.
cat > "$TMP/render.swift" <<'EOF'
import AppKit

let svgPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let canvas = 1024

guard let svg = NSImage(contentsOfFile: svgPath) else {
    fputs("cannot load \(svgPath)\n", stderr); exit(1)
}
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
svg.draw(in: NSRect(x: 0, y: 0, width: CGFloat(canvas), height: CGFloat(canvas)),
         from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: outPath))
EOF
swiftc -O "$TMP/render.swift" -o "$TMP/render"
"$TMP/render" img/logo.svg "$TMP/icon-1024.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$TMP/icon-1024.png" \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$TMP/icon-1024.png" \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o img/AppIcon.icns
echo "Wrote img/AppIcon.icns"
