onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+eth_tx_fifo -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.eth_tx_fifo xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {eth_tx_fifo.udo}

run -all

endsim

quit -force
