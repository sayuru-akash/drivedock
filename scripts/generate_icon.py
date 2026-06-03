#!/usr/bin/env python3
"""Generate DriveDock app icon with green gradient and white drive arrow icon."""

from PIL import Image, ImageDraw, ImageFont
import math
import os

def create_icon(size):
    """Create a single icon at the given size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw rounded rectangle background with green gradient
    padding = int(size * 0.05)
    corner_radius = int(size * 0.22)
    
    # Create gradient background
    for y in range(size):
        for x in range(size):
            # Check if pixel is within rounded rect
            in_rect = True
            cx, cy = corner_radius, corner_radius
            if x < corner_radius and y < corner_radius:
                dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                if dist > corner_radius:
                    in_rect = False
            cx2, cy2 = size - corner_radius, corner_radius
            if x > size - corner_radius and y < corner_radius:
                dist = math.sqrt((x - cx2)**2 + (y - cy2)**2)
                if dist > corner_radius:
                    in_rect = False
            cx3, cy3 = corner_radius, size - corner_radius
            if x < corner_radius and y > size - corner_radius:
                dist = math.sqrt((x - cx3)**2 + (y - cy3)**2)
                if dist > corner_radius:
                    in_rect = False
            cx4, cy4 = size - corner_radius, size - corner_radius
            if x > size - corner_radius and y > size - corner_radius:
                dist = math.sqrt((x - cx4)**2 + (y - cy4)**2)
                if dist > corner_radius:
                    in_rect = False
            
            if not (0 <= x < size and 0 <= y < size):
                in_rect = False
            if x < padding or x >= size - padding or y < padding or y >= size - padding:
                in_rect = False
            
            if in_rect:
                # Green gradient from top-left to bottom-right
                t = (x + y) / (2 * size)
                r = int(34 + t * 20)    # 34 -> 54
                g = int(180 + t * 40)   # 180 -> 220
                b = int(80 + t * 30)    # 80 -> 110
                img.putpixel((x, y), (r, g, b, 255))
    
    # Create mask for rounded rectangle
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [padding, padding, size - padding - 1, size - padding - 1],
        radius=corner_radius,
        fill=255
    )
    
    # Apply mask
    result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    result.paste(img, mask=mask)
    
    # Draw the drive-like icon (arrow pointing up with dock base)
    draw = ImageDraw.Draw(result)
    
    # Colors
    white = (255, 255, 255, 240)
    white_bright = (255, 255, 255, 255)
    
    center_x = size // 2
    center_y = size // 2
    
    # Draw upward arrow (cloud/drive upload symbol)
    arrow_width = int(size * 0.28)
    arrow_height = int(size * 0.22)
    arrow_top = int(size * 0.22)
    
    # Arrow head (triangle)
    arrow_tip_y = arrow_top
    arrow_base_y = arrow_top + arrow_height
    arrow_left = center_x - arrow_width
    arrow_right = center_x + arrow_width
    
    # Draw arrow shaft
    shaft_width = int(size * 0.12)
    shaft_top = arrow_base_y - int(size * 0.04)
    shaft_bottom = int(size * 0.55)
    
    draw.rectangle(
        [center_x - shaft_width, shaft_top, center_x + shaft_width, shaft_bottom],
        fill=white_bright
    )
    
    # Draw arrow head
    draw.polygon(
        [(center_x, arrow_tip_y), (arrow_left, arrow_base_y), (arrow_right, arrow_base_y)],
        fill=white_bright
    )
    
    # Draw dock base (two horizontal lines at bottom)
    base_y = int(size * 0.65)
    base_width = int(size * 0.35)
    base_height = int(size * 0.04)
    
    # First line
    draw.rounded_rectangle(
        [center_x - base_width, base_y, center_x + base_width, base_y + base_height],
        radius=int(size * 0.015),
        fill=white
    )
    
    # Second line
    base_y2 = base_y + int(size * 0.08)
    draw.rounded_rectangle(
        [center_x - base_width, base_y2, center_x + base_width, base_y2 + base_height],
        radius=int(size * 0.015),
        fill=white
    )
    
    # Third line (thinner)
    base_y3 = base_y2 + int(size * 0.08)
    base_width2 = int(size * 0.28)
    draw.rounded_rectangle(
        [center_x - base_width2, base_y3, center_x + base_width2, base_y3 + int(size * 0.03)],
        radius=int(size * 0.01),
        fill=(255, 255, 255, 180)
    )
    
    # Add subtle shadow/depth to arrow
    shadow_color = (20, 140, 60, 80)
    draw.polygon(
        [(center_x + 2, arrow_tip_y + 2), (arrow_left + 2, arrow_base_y + 2), (arrow_right + 2, arrow_base_y + 2)],
        fill=shadow_color
    )
    
    return result


def main():
    """Generate all icon sizes."""
    output_dir = "/Users/sayuru/Documents/GitHub/drivedock/DriveDock/Resources/Assets.xcassets/AppIcon.appiconset"
    
    # macOS icon sizes
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]
    
    # Generate at high resolution and resize
    master_size = 1024
    master_icon = create_icon(master_size)
    
    for base_size, scale in sizes:
        actual_size = base_size * scale
        icon = master_icon.resize((actual_size, actual_size), Image.LANCZOS)
        
        filename = f"icon_{base_size}x{base_size}{'@' + str(scale) + 'x' if scale > 1 else ''}.png"
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, 'PNG')
        print(f"Generated: {filename} ({actual_size}x{actual_size})")
    
    print(f"\nAll icons generated in: {output_dir}")


if __name__ == "__main__":
    main()
