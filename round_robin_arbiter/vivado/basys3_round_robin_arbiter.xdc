## basys3_round_robin_arbiter.xdc -- Basys3 (xc7a35tcpg236-1) constraints
## for top_round_robin_arbiter. Pin locations are the standard Digilent
## Basys3 master-XDC assignments; cross-check against your own board's
## official master XDC if in doubt.

## ---------------------------------------------------------------- clock
set_property PACKAGE_PIN W5 [get_ports sysclk]
set_property IOSTANDARD LVCMOS33 [get_ports sysclk]
create_clock -period 10.000 -name sysclk [get_ports sysclk]

## --------------------------------------------------------------- button
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## -------------------------------------------------- switches: sw[3:0] -> req
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

## --------------------------------------------------- LEDs: led[3:0] -> grant
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
