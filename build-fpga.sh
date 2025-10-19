#!/bin/bash

set -x
set -e

STAGING=_staging_
FPGA_AR=fpga.ar

rm -f ${FPGA_AR}
rm -rf ${STAGING}

vivado -mode batch -script flow.tcl
python3 extract-ila.py

mkdir ${STAGING}

cp out/fpga.bit ${STAGING}
cp ila.sig ${STAGING}

python3 create-archive.py ${FPGA_AR} _staging_/fpga.bit _staging_/ila.sig
