#!/usr/bin/env python3
from PIL import Image
import os
import shutil

# Source image path
source_image = r"c:\Users\realm\AppData\Roaming\Code\User\globalStorage\github.copilot-chat\copilot-cli-images\1779252021410-ft5333gd.png"

# Android icon sizes (density -> pixel size)
icon_sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192
}

# Project root
project_root = r"c:\Users\Ojt Project\flutter_application_1"

# Open the source image
img = Image.open(source_image)
print(f"Source image size: {img.size}")

# Generate resized icons for each density
for density, size in icon_sizes.items():
    # Create the output directory if it doesn't exist
    output_dir = os.path.join(project_root, "android", "app", "src", "main", "res", f"mipmap-{density}")
    os.makedirs(output_dir, exist_ok=True)
    
    # Resize and save
    resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
    output_path = os.path.join(output_dir, "ic_launcher.png")
    resized_img.save(output_path)
    print(f"✓ Created {density} ({size}x{size}): {output_path}")

print("\n✅ Android icons generated successfully!")
