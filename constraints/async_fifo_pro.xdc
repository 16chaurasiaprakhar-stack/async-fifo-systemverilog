#------------------------------------------------------------------------------
# Vivado Constraints File: async_fifo_pro.xdc
#------------------------------------------------------------------------------

# 1. Primary Clock Constraints
# Write Clock (100 MHz, 10.0 ns)
create_clock -period 10.000 -name wclk -waveform {0.000 5.000} [get_ports wclk]

# Read Clock (75 MHz, 13.333 ns)
create_clock -period 13.333 -name rclk -waveform {0.000 6.666} [get_ports rclk]

# 2. Asynchronous Clock Domain Groups (CDC)
# Tells Vivado timing engine that wclk and rclk are completely asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks wclk] \
    -group [get_clocks rclk]

# 3. Maximum Datapath Delay for Pointer Crossings (Bus Skew & Latency Control)
# Constrains the datapath delay across domains to prevent excessive routing skew
set_max_delay -from [get_cells -hierarchical *u_wptr_full/wptr_reg*] \
              -to   [get_cells -hierarchical *u_sync_w2r/sync_regs_reg[0]*] \
              10.000 -datapath_only

set_max_delay -from [get_cells -hierarchical *u_rptr_empty/rptr_reg*] \
              -to   [get_cells -hierarchical *u_sync_r2w/sync_regs_reg[0]*] \
              13.333 -datapath_only

# 4. Bus Skew Constraint (Enforces that Gray code bits arrive within 1 period)
set_bus_skew -from [get_cells -hierarchical *u_wptr_full/wptr_reg*] \
             -to   [get_cells -hierarchical *u_sync_w2r/sync_regs_reg[0]*] \
             2.500

set_bus_skew -from [get_cells -hierarchical *u_rptr_empty/rptr_reg*] \
             -to   [get_cells -hierarchical *u_sync_r2w/sync_regs_reg[0]*] \
             2.500
