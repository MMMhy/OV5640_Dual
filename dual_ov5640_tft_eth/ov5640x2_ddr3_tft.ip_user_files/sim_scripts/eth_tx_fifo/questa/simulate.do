onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib eth_tx_fifo_opt

do {wave.do}

view wave
view structure
view signals

do {eth_tx_fifo.udo}

run -all

quit -force
