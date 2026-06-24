vlib work
vlog ../rtl/uart_rx.sv \
     ../tb/tb_uart_rx.sv
vsim -c tb_uart_rx -do "run -all; quit"
