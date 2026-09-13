## basys3_async_fifo.xdc -- Basys3 (xc7a35tcpg236-1) constraints for top_async_fifo
## Pin locations are the standard Digilent Basys3 master-XDC assignments;
## cross-check against your own board's official master XDC if in doubt.

## ---------------------------------------------------------------- clock
set_property PACKAGE_PIN W5 [get_ports sysclk]
set_property IOSTANDARD LVCMOS33 [get_ports sysclk]
create_clock -period 10.000 -name sysclk [get_ports sysclk]

## --------------------------------------------------------------- buttons
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property PACKAGE_PIN T18 [get_ports btnU]
set_property PACKAGE_PIN U17 [get_ports btnD]
set_property IOSTANDARD LVCMOS33 [get_ports {btnC btnU btnD}]

## -------------------------------------------------- switches: sw[7:0] -> wr_data
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

## ------------------------------------------------------------------ LEDs
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property PACKAGE_PIN V13 [get_ports {led[8]}]
set_property PACKAGE_PIN V3  [get_ports {led[9]}]
set_property PACKAGE_PIN W3  [get_ports {led[10]}]
set_property PACKAGE_PIN U3  [get_ports {led[11]}]
set_property PACKAGE_PIN P3  [get_ports {led[12]}]
set_property PACKAGE_PIN N3  [get_ports {led[13]}]
set_property PACKAGE_PIN P1  [get_ports {led[14]}]
set_property PACKAGE_PIN L1  [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## ------------------------------------------------- MMCM-generated clocks
## VCO = sysclk * 8; wr_clk = VCO/12 = 66.667 MHz; rd_clk = VCO/7 = 114.286 MHz
create_generated_clock -name wr_clk \
    -source [get_pins u_mmcm/CLKIN1] -multiply_by 8 -divide_by 12 \
    [get_pins u_mmcm/CLKOUT0]

create_generated_clock -name rd_clk \
    -source [get_pins u_mmcm/CLKIN1] -multiply_by 8 -divide_by 7 \
    [get_pins u_mmcm/CLKOUT1]

## wr_clk and rd_clk cross only through the FIFO's own Gray-code
## synchronizers (verified in simulation) -- tell the STA engine they are
## unrelated so it doesn't flag those crossings as ordinary setup/hold
## violations.
set_clock_groups -asynchronous -group [get_clocks wr_clk] -group [get_clocks rd_clk]
