@echo off
setlocal
echo ===================================================================
echo Compiling Production Async FIFO Verification Suite (Icarus Verilog)
echo ===================================================================

iverilog -g2012 -o async_fifo_sim.vvp rtl\cdc_sync.sv rtl\async_fifo_mem.sv rtl\wptr_full_ctrl.sv rtl\rptr_empty_ctrl.sv rtl\async_fifo_pro.sv tb\async_fifo_sva.sv tb\async_fifo_pro_tb.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo ===================================================================
echo Running Simulation with VVP...
echo ===================================================================
vvp async_fifo_sim.vvp

echo.
echo Simulation finished. Waveforms saved to async_fifo_pro.vcd.
echo To inspect in GTKWave: gtkwave async_fifo_pro.vcd
endlocal
