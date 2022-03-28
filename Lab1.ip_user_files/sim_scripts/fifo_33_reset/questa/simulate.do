onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib fifo_33_reset_opt

do {wave.do}

view wave
view structure
view signals

do {fifo_33_reset.udo}

run -all

quit -force
