import machine
import time

fpga_power = machine.Pin(46, machine.Pin.OUT)
fpga_done = machine.Pin(6, machine.Pin.IN)
fpga_program_b = machine.Pin(7, machine.Pin.OPEN_DRAIN, value=1)
fpga_init_b = machine.Pin(8, machine.Pin.IN)
fpga_spi_cs = machine.Pin(10, machine.Pin.OUT)

def program_fpga(bitstream):
  print("Powering on FPGA")
  fpga_power.value(1)
  fpga_spi_cs.value(1)

  fpga_spi = machine.SPI(2, baudrate=80_000_000, sck=machine.Pin(12), mosi=machine.Pin(11), miso=machine.Pin(13))

  time.sleep_ms(100)
  fpga_program_b.value(0)
  time.sleep_ms(50)

  print("init_b (should be 0):", fpga_init_b.value())
  fpga_program_b.value(1)
  while fpga_init_b.value() == 0:
    print("waiting for init_b...")
    time.sleep_ms(50)

  print("FPGA is in program mode.")
  print("programming:", bitstream)
  f = open(bitstream, 'rb')
  f.read(129) # discard header

  chunk_size = 16 * 1024
  while True:
    data = f.read(chunk_size)
    if len(data) == 0:
      break
    fpga_spi.write(data)

  time.sleep_ms(100)
  print("Done pin (should be 1):", fpga_done.value())
