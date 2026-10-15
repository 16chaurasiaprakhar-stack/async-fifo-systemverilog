#------------------------------------------------------------------------------
# Constraints: async_fifo_pro.sdc
# Purpose: Industry-Standard SDC/XDC for Production Asynchronous FIFO
# Tools: Synopsys PrimeTime, Cadence Tempus, AMD Vivado, Intel Quartus
#------------------------------------------------------------------------------

# 1. Primary Clock Definitions
create_clock -name wclk -period 10.000 [get_ports wclk]
create_clock -name rclk -period 13.333 [get_ports rclk]

# 2. Clock Uncertainties
set_clock_uncertainty 0.150 [get_clocks wclk]
set_clock_uncertainty 0.150 [get_clocks rclk]

# 3. Asynchronous Clock Domain Groups
# Defines wclk and rclk as completely asynchronous (CDC)
set_clock_groups -asynchronous \
    -group [get_clocks wclk] \
    -group [get_clocks rclk]

# 4. CDC Gray Pointer Datapath & Bus Skew Constraints
# The Gray pointer bus must cross clock domains with minimal skew between bits
# to ensure only 1 bit is ever observed transitioning at the receiving domain.
set_max_delay -from [get_cells -hier *u_wptr_full/wptr_reg*] \
              -to   [get_cells -hier *u_sync_w2r/sync_regs_reg[0]*] \
              10.000 -datapath_only

set_max_delay -from [get_cells -hier *u_rptr_empty/rptr_reg*] \
              -to   [get_cells -hier *u_sync_r2w/sync_regs_reg[0]*] \
              13.333 -datapath_only

# Enforce bus skew constraint across all bits of the Gray pointer bus (Xilinx / Synopsys)
# set_bus_skew -from [get_cells -hier *u_wptr_full/wptr_reg*] -to [get_cells -hier *u_sync_w2r/sync_regs_reg[0]*] 2.000
# set_bus_skew -from [get_cells -hier *u_rptr_empty/rptr_reg*] -to [get_cells -hier *u_sync_r2w/sync_regs_reg[0]*] 2.000
