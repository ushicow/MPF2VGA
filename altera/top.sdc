create_clock -name "clock" -period 39.722ns [get_ports {clk}]
create_clock -name "Q3" -period 490.000ns [get_ports {pAq3}] -waveform {0.000 280.000}

set_input_delay -clock { Q3 } -max 0 [get_ports {pAaddr[*]}]
set_input_delay -clock { Q3 } -max 0 [get_ports {pAdata[*}]
set_input_delay -clock { Q3 } -max 0 [get_ports {pArw pAphi0 pAphi0}]
set_input_delay -clock { clock } -max 25 [get_ports {pVdata[*]}]

set_false_path -from [get_ports {reset}]