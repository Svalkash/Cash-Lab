vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/fifo_generator_v13_2_4
vlib modelsim_lib/msim/xil_defaultlib

vmap fifo_generator_v13_2_4 modelsim_lib/msim/fifo_generator_v13_2_4
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work fifo_generator_v13_2_4 -64 -incr \
"../../../ipstatic/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_4 -64 -93 \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_4 -64 -incr \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work xil_defaultlib -64 -incr \
"../../../../Lab1.srcs/sources_1/ip/fifo_32/sim/fifo_32.v" \


vlog -work xil_defaultlib \
"glbl.v"

