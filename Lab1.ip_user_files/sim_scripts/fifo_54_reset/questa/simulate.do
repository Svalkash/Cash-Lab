onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib fifo_54_reset_opt

do {wave.do}

view wave
view structure
view signals

do {fifo_54_reset.udo}

run -all

quit -force
