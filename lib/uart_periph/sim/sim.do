vlib work
vlog ../../uart_tx/rtl/uart_tx.sv \
     ../../uart_rx/rtl/uart_rx.sv \
     ../rtl/uart_periph.sv \
     ../tb/tb_uart_periph.sv
vsim -c tb_uart_periph -do "run -all; quit"
