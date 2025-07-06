#include <array>
#include <cstdint>
#include <fstream>

constexpr unsigned width = 320;
constexpr unsigned height = 200;

std::array<uint8_t, width * height / 2> image = {};

void setPixel(unsigned x, unsigned y, uint8_t color) {
  unsigned idx = y * width / 2 + x / 2;
  uint8_t tmp = image[idx];
  if ((x % 2) == 0) {
    tmp = (tmp & 0x0f) | color << 4;
  } else {
    tmp = (tmp & 0xf0) | color & 0xf;
  }
  image[idx] = tmp;
}

int main(int argc, char *argv[]) {
  std::ofstream os;
  os.open(argv[1], std::ios::out | std::ios::binary);

  for (unsigned x = 0; x < width; x++) {
    setPixel(x, height / 10 * 1, 0x9);
    setPixel(x, height / 10 * 5, 0x9);
    setPixel(x, height / 10 * 9, 0x9);
  }

  for (unsigned y = 0; y < height; y++) {
    setPixel(width / 10 * 1, y, 0xd);
    setPixel(width / 10 * 5, y, 0xd);
    setPixel(width / 10 * 9, y, 0xd);
  }

  os.write(reinterpret_cast<const char *>(image.data()), image.size());

  os.close();

  return 0;
}
