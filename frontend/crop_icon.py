import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow library is not installed. Please run 'pip install Pillow' to install it.")
    sys.exit(1)

def crop_center(img_path, out_path, crop_factor):
    if not os.path.exists(img_path):
        print(f"Error: Input file '{img_path}' not found.")
        return
        
    img = Image.open(img_path)
    width, height = img.size
    
    # Calculate new dimensions
    new_width = int(width * crop_factor)
    new_height = int(height * crop_factor)
    
    left = int((width - new_width) / 2)
    top = int((height - new_height) / 2)
    right = int((width + new_width) / 2)
    bottom = int((height + new_height) / 2)
    
    # Crop the center of the image
    cropped_img = img.crop((left, top, right, bottom))
    
    # Handle Pillow version compatibility for resampling filter (LANCZOS / ANTIALIAS)
    if hasattr(Image, 'Resampling'):
        resample_filter = Image.Resampling.LANCZOS
    else:
        resample_filter = getattr(Image, 'LANCZOS', getattr(Image, 'ANTIALIAS', Image.BICUBIC))
        
    final_img = cropped_img.resize((width, height), resample_filter)
    
    os.makedirs(os.path.dirname(out_path) or '.', exist_ok=True)
    final_img.save(out_path)
    print(f"Saved cropped image to {out_path}")

if __name__ == "__main__":
    # Resolve paths relative to script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_path = os.path.join(script_dir, "assets", "images", "app_icon.png")
    output_path = os.path.join(script_dir, "assets", "images", "app_icon_fg.png")
    
    # Crop to central 75% to remove white edges/corners
    crop_center(input_path, output_path, 0.75)

