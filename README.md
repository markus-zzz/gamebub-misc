# GameBub stuff
This repository contains scripts, code, notes and other stuff that I gathered
to play around with and explore the
[GameBub](https://github.com/elipsitz/gamebub) platform.

## Prerequisites

### FPGA
Install AMD/Xilinx
[Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
with support for Artix-7 FPGAs.

### ESP32

#### Tools
Install [esptool](https://docs.espressif.com/projects/esptool/en/latest/esp32/) and [adafruit-ampy](https://pypi.org/project/adafruit-ampy/)
```
$ pip install esptool
$ pip install adafruit-ampy
```

#### MicroPython
Download and install [MicroPython](https://micropython.org/download/ESP32_GENERIC_S3/) on the ESP32 MCU.
```
$ esptool.py erase_flash
$ esptool.py --baud 460800 write_flash 0 ~/Downloads/ESP32_GENERIC_S3-20250415-v1.25.0.bin
```

## Minimal Vivado CLI flow
Setup the environment
```
$ source tools/Xilinx/Vivado/2024.2/settings64.sh
```
Run the flow
```
$ vivado -mode tcl -script flow.tcl
```

## Deploy
Upload the bitstream and python code to ESP32 flash
```
$ ampy --port /dev/ttyACM0 put fpgamisc.py
$ ampy --port /dev/ttyACM0 put pmod.bit
```

## Run
Connect and program the FPGA
```
$ minicom -D /dev/ttyACM0
>>> import fpgamisc
>>> fpgamisc.program_fpga('pmod.bit')
```
and at this point 500Hz, 250Hz, 125Hz and 62.5Hz square waves can be observed on the
`PMOD[3:0]` port of the board.

(Note that the `CTRL-A` key combination, used to exit minicom, also puts the
MicroPython in `raw REPL mode`. Use `CTRL-B` to bring it back to `normal REPL
mode`).

### Program FPGA over WiFi
Alternatively one can also program the FPGA over WiFi. First start the
programmer server. E.g.
```
>>> fpgamisc.program_fpga_wifi('wireless_1', 'top-secret-password')
```
Then, from the host, use netcat to to connect to port 1234 of the device and
download the desired bitstream. E.g.
```
nc -N 192.168.2.227 1234 < out/pmod.bit
```

### Misc

Generate RGB data for the bouncing image. E.g.
```
$ python3 python/rgb-tool.py ~/Downloads/parrot.jpg 128 128 > image.dat
```

Do this in the Python REPL after boot
```
# Turn off status LED as it is too bright
import machine
status_led = machine.Pin(36, machine.Pin.OUT)
status_led.value(0)

# Setup LCD
import lcd
lcd = lcd.LCD()
lcd.setup()

# Connect to WIFI and get ready to program FPGA
import fpgamisc
fpgamisc.wifi_connect('network', 'password')
fpgamisc.fpga_program_server()
```

## Firmware

```
$ idf.py set-target esp32s3
$ idf.py menuconfig
$ idf.py build flash monitor
```

## Web-based ILA

The http server hosts the user interface for a small Integrated Logic Analyzer
(ILA) with an embedded https://surfer-project.org/ waveform viewer.

For various, web-technical, reasons it turned out that the most straight
forward approach was to have the http server also host the Surfer WASM (instead
of using the publicly hosted https://app.surfer-project.org/).

### Setup

First enter `idf.py menuconfig` and be sure to enable `Component config -> FAT
Filesystem support -> Long filename support`.

Then populate the SD Card with the following contents from
`https://gitlab.com/surfer-project/surfer/-/jobs/artifacts/main/download?job=pages_build`
```
/media/surfer.html
/media/dist
/media/dist/integration.js
/media/dist/manifest.json
/media/dist/surfer.d.ts
/media/dist/surfer.js
/media/dist/surfer_bg.wasm
/media/dist/sw.js
```
and from `firmware/html`
```
/media/index.html
```
