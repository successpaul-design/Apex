#!/usr/bin/env python3
"""Generate a professional app icon for HuffScan floor plan scanner."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE))
draw = ImageDraw.Draw(img)

# --- Background gradient (deep teal to dark blue) ---
for y in range(SIZE):
    t = y / SIZE
    r = int(10 + t * 15)
    g = int(40 + (1 - t) * 60)
    b = int(80 + (1 - t) * 90)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

# --- Subtle radial glow in center ---
glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
cx, cy = SIZE // 2, SIZE // 2 - 40
for radius in range(400, 0, -1):
    intensity = int(45 * (1 - radius / 400) ** 2)
    glow_draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=(intensity, intensity + 10, intensity + 15),
    )
glow = glow.filter(ImageFilter.GaussianBlur(30))
img = Image.eval(img, lambda x: x)  # copy
from PIL import ImageChops
img = ImageChops.add(img, glow)
draw = ImageDraw.Draw(img)

# --- Floor plan parameters ---
# Outer walls
margin = 200
wall_thickness = 18
plan_left = margin
plan_top = margin - 30
plan_right = SIZE - margin
plan_bottom = SIZE - margin - 60
plan_w = plan_right - plan_left
plan_h = plan_bottom - plan_top

wall_color = (220, 235, 255)
wall_color_bright = (255, 255, 255)
door_color = (100, 180, 240)
dim_color = (140, 190, 230)
grid_color = (30, 60, 100)

# --- Draw subtle grid ---
for gx in range(0, SIZE, 64):
    draw.line([(gx, 0), (gx, SIZE)], fill=grid_color, width=1)
for gy in range(0, SIZE, 64):
    draw.line([(0, gy), (SIZE, gy)], fill=grid_color, width=1)

# --- Draw outer walls ---
def draw_wall(x1, y1, x2, y2, thickness=wall_thickness):
    draw.rectangle([x1, y1, x2, y2], fill=wall_color_bright)

# Outer rectangle walls
draw_wall(plan_left, plan_top, plan_right, plan_top + wall_thickness)  # top
draw_wall(plan_left, plan_bottom - wall_thickness, plan_right, plan_bottom)  # bottom
draw_wall(plan_left, plan_top, plan_left + wall_thickness, plan_bottom)  # left
draw_wall(plan_right - wall_thickness, plan_top, plan_right, plan_bottom)  # right

# --- Interior walls ---
# Vertical wall dividing left third
vwall_x = plan_left + int(plan_w * 0.38)
draw_wall(vwall_x, plan_top, vwall_x + wall_thickness, plan_top + int(plan_h * 0.55))

# Horizontal wall dividing top-right area
hwall_y = plan_top + int(plan_h * 0.55)
draw_wall(vwall_x, hwall_y, plan_right, hwall_y + wall_thickness)

# Small bathroom wall in top-right
bath_x = plan_right - int(plan_w * 0.28)
draw_wall(bath_x, plan_top, bath_x + wall_thickness, hwall_y)

# Bottom horizontal wall for hallway
hall_y = plan_bottom - int(plan_h * 0.35)
draw_wall(plan_left, hall_y, vwall_x, hall_y + wall_thickness)

# --- Door arcs ---
def draw_door_arc(cx, cy, radius, start_angle, end_angle, opening_dir="right"):
    """Draw a door swing arc."""
    bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
    draw.arc(bbox, start_angle, end_angle, fill=door_color, width=3)
    # Door line
    rad = math.radians(start_angle if opening_dir == "right" else end_angle)
    ex = cx + radius * math.cos(rad)
    ey = cy + radius * math.sin(rad)
    draw.line([(cx, cy), (ex, ey)], fill=door_color, width=3)

# Door in vertical interior wall (opens right)
door1_y = plan_top + int(plan_h * 0.32)
draw.rectangle([vwall_x - 2, door1_y, vwall_x + wall_thickness + 2, door1_y + 50], fill=(15, 45, 85))
draw_door_arc(vwall_x + wall_thickness + 2, door1_y + 50, 48, 270, 360)

# Door in bottom-left room
door2_x = plan_left + int(plan_w * 0.15)
draw.rectangle([door2_x, hall_y - 2, door2_x + 50, hall_y + wall_thickness + 2], fill=(15, 45, 85))
draw_door_arc(door2_x, hall_y + wall_thickness + 2, 48, 270, 360)

# Door opening in horizontal wall (right side)
door3_x = vwall_x + int(plan_w * 0.15)
draw.rectangle([door3_x, hwall_y - 2, door3_x + 55, hwall_y + wall_thickness + 2], fill=(15, 45, 85))

# Front door (bottom wall)
front_x = plan_left + int(plan_w * 0.55)
draw.rectangle([front_x, plan_bottom - wall_thickness - 2, front_x + 60, plan_bottom + 2], fill=(15, 45, 85))
draw_door_arc(front_x, plan_bottom - wall_thickness - 2, 55, 0, 90)

# --- Dimension lines ---
def draw_dimension(x1, y1, x2, y2):
    draw.line([(x1, y1), (x2, y2)], fill=dim_color, width=2)
    # end ticks
    if y1 == y2:  # horizontal
        draw.line([(x1, y1 - 6), (x1, y1 + 6)], fill=dim_color, width=2)
        draw.line([(x2, y2 - 6), (x2, y2 + 6)], fill=dim_color, width=2)
    else:  # vertical
        draw.line([(x1 - 6, y1), (x1 + 6, y1)], fill=dim_color, width=2)
        draw.line([(x2 - 6, y2), (x2 + 6, y2)], fill=dim_color, width=2)

# Top dimension
draw_dimension(plan_left, plan_top - 35, plan_right, plan_top - 35)
# Left dimension
draw_dimension(plan_left - 35, plan_top, plan_left - 35, plan_bottom)
# Room width dimension
draw_dimension(plan_left + wall_thickness, hwall_y + 45, vwall_x, hwall_y + 45)

# --- Measurement dots at corners ---
dot_r = 5
corners = [
    (plan_left, plan_top), (plan_right, plan_top),
    (plan_left, plan_bottom), (plan_right, plan_bottom),
    (vwall_x, plan_top), (vwall_x, hwall_y),
    (bath_x, plan_top), (bath_x, hwall_y),
]
for cx, cy in corners:
    draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=door_color)

# --- Scan line effect (like LiDAR scanning) ---
scan_y = plan_top + int(plan_h * 0.7)
for i in range(SIZE):
    alpha = max(0, 80 - abs(i - scan_y) * 2)
    if alpha > 0:
        scan_color = (50 + alpha, 150 + min(alpha, 60), 230)
        draw.line([(plan_left - 20, i), (plan_right + 20, i)], fill=scan_color, width=1)

# --- "HuffScan" text at bottom ---
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72)
    small_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 36)
except OSError:
    font = ImageFont.load_default()
    small_font = font

text = "HuffScan"
bbox_text = draw.textbbox((0, 0), text, font=font)
tw = bbox_text[2] - bbox_text[0]
text_x = (SIZE - tw) // 2
text_y = plan_bottom + 45

# Text shadow
draw.text((text_x + 2, text_y + 2), text, fill=(5, 20, 40), font=font)
# Main text
draw.text((text_x, text_y), text, fill=(220, 240, 255), font=font)

# --- Save ---
output_path = "HuffScan/HuffScan/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
img.save(output_path, "PNG")
print(f"Icon saved to {output_path}")
print(f"Size: {img.size}")
