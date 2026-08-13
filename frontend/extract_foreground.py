"""
Extract the orange bat + ball from the ScorePartner icon
onto a transparent background for Android adaptive icon foreground.

Uses saturation-based color keying with smooth alpha transitions
for clean anti-aliased edges.
"""
import os
import sys
import colorsys

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow library is not installed. Run: pip install Pillow")
    sys.exit(1)


def extract_foreground(src_path, dst_path, canvas_size=1024):
    """
    Extract high-saturation orange elements (bat + ball) from the peach
    background, outputting a transparent PNG.
    """
    img = Image.open(src_path).convert("RGB")
    w, h = img.size

    # Sample corners to determine precise background color
    corners = [
        img.getpixel((5, 5)),
        img.getpixel((w - 5, 5)),
        img.getpixel((5, h - 5)),
        img.getpixel((w - 5, h - 5)),
    ]
    bg_r = sum(c[0] for c in corners) / 4
    bg_g = sum(c[1] for c in corners) / 4
    bg_b = sum(c[2] for c in corners) / 4
    print(f"Detected background color: RGB({bg_r:.0f}, {bg_g:.0f}, {bg_b:.0f})")

    # Create output RGBA image
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src_pixels = img.load()
    out_pixels = out.load()

    # Thresholds for saturation-based keying
    SAT_LOW = 0.18
    SAT_HIGH = 0.45

    # Color distance thresholds
    DIST_LOW = 25
    DIST_HIGH = 100

    for y in range(h):
        for x in range(w):
            r, g, b = src_pixels[x, y]

            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h_val, s_val, v_val = colorsys.rgb_to_hsv(rf, gf, bf)

            dist = ((r - bg_r) ** 2 + (g - bg_g) ** 2 + (b - bg_b) ** 2) ** 0.5

            if s_val <= SAT_LOW:
                alpha_sat = 0.0
            elif s_val >= SAT_HIGH:
                alpha_sat = 1.0
            else:
                alpha_sat = (s_val - SAT_LOW) / (SAT_HIGH - SAT_LOW)

            if dist <= DIST_LOW:
                alpha_dist = 0.0
            elif dist >= DIST_HIGH:
                alpha_dist = 1.0
            else:
                alpha_dist = (dist - DIST_LOW) / (DIST_HIGH - DIST_LOW)

            alpha = max(alpha_sat, alpha_dist)

            if alpha < 0.01:
                out_pixels[x, y] = (0, 0, 0, 0)
            elif alpha > 0.99:
                out_pixels[x, y] = (r, g, b, 255)
            else:
                fg_r = min(255, max(0, int((r - (1 - alpha) * bg_r) / alpha)))
                fg_g = min(255, max(0, int((g - (1 - alpha) * bg_g) / alpha)))
                fg_b = min(255, max(0, int((b - (1 - alpha) * bg_b) / alpha)))
                out_pixels[x, y] = (fg_r, fg_g, fg_b, int(alpha * 255))

    os.makedirs(os.path.dirname(dst_path) or ".", exist_ok=True)
    out.save(dst_path, "PNG")
    print(f"Saved transparent foreground to: {dst_path}")
    print(f"Output size: {out.size}, mode: {out.mode}")

    total = w * h
    transparent = sum(1 for y in range(h) for x in range(w) if out_pixels[x, y][3] == 0)
    opaque = sum(1 for y in range(h) for x in range(w) if out_pixels[x, y][3] == 255)
    semi = total - transparent - opaque
    print(f"Pixels: {transparent} transparent, {opaque} opaque, {semi} semi-transparent (total {total})")


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    src = os.path.join(script_dir, "assets", "images", "app_icon_fg.png")
    dst = os.path.join(script_dir, "assets", "images", "app_icon_foreground.png")
    extract_foreground(src, dst)
