import os
import struct
import argparse

def create_archive(output_filename, input_files):
    with open(output_filename, 'wb') as archive:
        for file_path in input_files:
            if not os.path.isfile(file_path):
                print(f"Skipping {file_path}: not a file")
                continue

            filename = os.path.basename(file_path).encode('utf-8')
            filesize = os.path.getsize(file_path)

            if len(filename) > 255:
                print(f"Skipping {file_path}: filename too long")
                continue
            if filesize > 0xFFFFFFFF:
                print(f"Skipping {file_path}: file too large")
                continue

            archive.write(struct.pack('B', len(filename)))  # 1 byte for filename length
            archive.write(filename)                         # filename bytes
            archive.write(struct.pack('I', filesize))       # 4 bytes for file size

            with open(file_path, 'rb') as f:
                archive.write(f.read())

    print(f"✅ Archive created: {output_filename}")

def main():
    parser = argparse.ArgumentParser(description="Create a simple binary archive.")
    parser.add_argument("output", help="Output archive filename")
    parser.add_argument("files", nargs='+', help="Files to include in the archive")

    args = parser.parse_args()
    create_archive(args.output, args.files)

if __name__ == "__main__":
    main()
