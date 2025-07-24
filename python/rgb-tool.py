from PIL import Image
import numpy as np
import sys

def main():
    if len(sys.argv) != 4:
        print("Usage: python rgb-tool.py <image_path> <width> <height>")
        return

    image_path = sys.argv[1]
    width = int(sys.argv[2])
    height = int(sys.argv[3])

    img = Image.open(image_path)
    img = img.resize((width, height))
    rgb_array = np.array(img)

    for rgb_row in rgb_array:
      for rgb in rgb_row:
        rgb_666 = (rgb / 255.) * 0x3f
        print(format((int(rgb_666[0]) << 12) | (int(rgb_666[1]) << 6) | (int(rgb_666[2]) << 0), '05x'))


if __name__ == "__main__":
    main()

