@echo off
setlocal
echo ===================================================================
echo Compiling Academic Async FIFO (Style #2) with Icarus Verilog...
echo ===================================================================

cd style2_academic
iverilog -g2012 -o style2_sim.vvp rtl\fifomem.sv rtl\async_cmp.sv rtl\rptr_empty.sv rtl\wptr_full.sv rtl\fifo2_top.sv tb\fifo_assertions.sv tb\tb_fifo2.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    cd ..
    exit /b %ERRORLEVEL%
)

echo.
echo ===================================================================
echo Running Style #2 Simulation with VVP...
echo ===================================================================
vvp style2_sim.vvp

echo.
echo Simulation finished. Waveforms saved to style2_academic\async_fifo.vcd.
cd ..
endlocal
