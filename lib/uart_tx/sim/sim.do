vlib work
vlog ../rtl/uart_tx.sv \
     ../tb/tb_uart_tx.sv
vsim -c tb_uart_tx -do "run -all; quit"
