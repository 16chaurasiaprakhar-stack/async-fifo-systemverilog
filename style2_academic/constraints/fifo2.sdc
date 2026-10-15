#------------------------------------------------------------------------------
# Constraints: fifo2.sdc
# Purpose: Synopsys Design Constraints (SDC) for Asynchronous FIFO (Style #2)
# Applicable to: Synopsys PrimeTime, Cadence Tempus, Xilinx Vivado (XDC)
#------------------------------------------------------------------------------

# 1. Define Primary Asynchronous Clocks
# wclk = 100 MHz (10.0 ns)
create_clock -name wclk -period 10.000 [get_ports wclk]

# rclk = 75.18 MHz (13.3 ns)
create_clock -name rclk -period 13.300 [get_ports rclk]

# 2. Clock Uncertainty (Jitter & Skew margin)
set_clock_uncertainty 0.200 [get_clocks wclk]
set_clock_uncertainty 0.200 [get_clocks rclk]

# 3. Asynchronous Clock Domain Groups
# Declare wclk and rclk as mutually asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks wclk] \
    -group [get_clocks rclk]

# 4. Critical Path Constraints for Asynchronous Comparator (Section 5.3.6)
# The asynchronous comparator and preset signals (aempty_n, afull_n) cross domains.
# To prevent excessive routing skew between the bit lines of wptr and rptr,
# constrain maximum datapath delay between the pointer registers and comparator:
set_max_delay -from [get_cells u_wptr_full/wptr_reg*] -to [get_cells u_wptr_full/wfull_reg*] 5.000 -datapath_only
set_max_delay -from [get_cells u_rptr_empty/rptr_reg*] -to [get_cells u_rptr_empty/rempty_reg*] 6.000 -datapath_only

# 5. False Paths for 2-Stage Synchronizer Flops (Deassertion timing)
# Removal of aempty_n and afull_n is captured by 2-FF synchronizers to avoid metastability.
set_false_path -to [get_pins -hier *rempty2_reg*/D]
set_false_path -to [get_pins -hier *wfull2_reg*/D]
