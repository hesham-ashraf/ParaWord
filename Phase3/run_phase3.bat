@echo off
REM Phase 3 - Fault-Tolerant Word Counter
REM Build and Run Script
REM Author: Hesham Ashraf, Ahmed Sameh
REM Date: December 28, 2025

setlocal EnableDelayedExpansion

echo ========================================
echo Phase 3 - Fault-Tolerant System
echo ========================================
echo.

REM Check if MPI is available
where mpiexec >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] MPI not found in PATH
    echo [INFO] Install MS-MPI from: https://docs.microsoft.com/en-us/message-passing-interface/microsoft-mpi
    echo.
    pause
    exit /b 1
)

echo [OK] MPI found
echo.

REM Change to Phase3 directory if not already there
if not exist "src\word_count_resilient.cpp" (
    if exist "..\Phase3\src\word_count_resilient.cpp" (
        cd ..\Phase3
    ) else if exist "Phase3\src\word_count_resilient.cpp" (
        cd Phase3
    ) else (
        echo [ERROR] Cannot find Phase3 directory
        pause
        exit /b 1
    )
)

REM Menu
:menu
cls
echo ========================================
echo Phase 3 - Fault-Tolerant System Menu
echo ========================================
echo.
echo 1. Compile Phase 3
echo 2. Run Basic Test (6 processes)
echo 3. Run Single Failure Test
echo 4. Run Multiple Failures Test
echo 5. Run Fault Injection Test
echo 6. Measure Performance
echo 7. Clean Build Files
echo 8. Exit
echo.
echo ========================================
set /p choice="Select option (1-8): "

if "%choice%"=="1" goto compile
if "%choice%"=="2" goto run_basic
if "%choice%"=="3" goto run_single_failure
if "%choice%"=="4" goto run_multiple_failures
if "%choice%"=="5" goto run_fault_injection
if "%choice%"=="6" goto performance
if "%choice%"=="7" goto clean
if "%choice%"=="8" goto end
goto menu

:compile
echo.
echo ========================================
echo Compiling Phase 3...
echo ========================================
echo.

REM Check for C++ compiler
where mpic++ >nul 2>&1
if %errorLevel% EQU 0 (
    echo [INFO] Using mpic++ compiler
    mpic++ -std=c++17 -O2 -o word_count_resilient src\word_count_resilient.cpp src\checkpoint.cpp
    goto check_compile
)

where g++ >nul 2>&1
if %errorLevel% EQU 0 (
    echo [INFO] Using g++ with MPI
    g++ -std=c++17 -O2 -I"C:\Program Files (x86)\Microsoft SDKs\MPI\Include" -L"C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64" -o word_count_resilient src\word_count_resilient.cpp src\checkpoint.cpp -lmsmpi
    goto check_compile
)

echo [ERROR] No suitable C++ compiler found
echo [INFO] Install mpic++ or g++ with MPI support
pause
goto menu

:check_compile
if exist "word_count_resilient.exe" (
    echo.
    echo [OK] Compilation successful: word_count_resilient.exe
    echo.
) else (
    echo.
    echo [ERROR] Compilation failed
    echo.
)
pause
goto menu

:run_basic
echo.
echo ========================================
echo Running Basic Test (6 processes)
echo ========================================
echo.

if not exist "word_count_resilient.exe" (
    echo [ERROR] Executable not found. Please compile first (Option 1)
    pause
    goto menu
)

if not exist "scripts\sample2.txt" (
    echo [WARNING] Sample file not found in scripts\
    echo [INFO] Using src\sample2.txt if available
    if exist "src\sample2.txt" (
        set INPUT_FILE=src\sample2.txt
    ) else (
        echo [ERROR] No input file found
        pause
        goto menu
    )
) else (
    set INPUT_FILE=scripts\sample2.txt
)

echo [INFO] Running: mpiexec -n 6 word_count_resilient.exe %INPUT_FILE%
echo.
mpiexec -n 6 word_count_resilient.exe %INPUT_FILE%
echo.
echo [INFO] Test completed
pause
goto menu

:run_single_failure
echo.
echo ========================================
echo Running Single Failure Test
echo ========================================
echo.

if exist "scripts\test_single_failure.ps1" (
    echo [INFO] Running PowerShell test script...
    powershell -ExecutionPolicy Bypass -File scripts\test_single_failure.ps1
) else (
    echo [WARNING] test_single_failure.ps1 not found
    echo [INFO] Running manual single failure test...
    echo.
    
    if not exist "word_count_resilient.exe" (
        echo [ERROR] Executable not found. Please compile first (Option 1)
        pause
        goto menu
    )
    
    echo Starting 6 processes with simulated failure...
    mpiexec -n 6 word_count_resilient.exe scripts\sample2.txt
)

echo.
pause
goto menu

:run_multiple_failures
echo.
echo ========================================
echo Running Multiple Failures Test
echo ========================================
echo.

if exist "scripts\test_multiple_failures.ps1" (
    echo [INFO] Running PowerShell test script...
    powershell -ExecutionPolicy Bypass -File scripts\test_multiple_failures.ps1
) else (
    echo [WARNING] test_multiple_failures.ps1 not found
    echo [INFO] Running manual multiple failures test...
    echo.
    
    if not exist "word_count_resilient.exe" (
        echo [ERROR] Executable not found. Please compile first (Option 1)
        pause
        goto menu
    )
    
    echo Starting 8 processes with multiple simulated failures...
    mpiexec -n 8 word_count_resilient.exe scripts\sample2.txt
)

echo.
pause
goto menu

:run_fault_injection
echo.
echo ========================================
echo Running Fault Injection Test
echo ========================================
echo.

set /p num_procs="Enter number of processes (default 8): "
if "%num_procs%"=="" set num_procs=8

set /p num_fails="Enter number of failures (default 2): "
if "%num_fails%"=="" set num_fails=2

if exist "scripts\test_fault_injection.ps1" (
    echo [INFO] Running fault injection with %num_procs% processes, %num_fails% failures...
    powershell -ExecutionPolicy Bypass -File scripts\test_fault_injection.ps1 -NumProcesses %num_procs% -NumFailures %num_fails%
) else (
    echo [WARNING] test_fault_injection.ps1 not found
    echo [INFO] Running basic test with %num_procs% processes...
    
    if not exist "word_count_resilient.exe" (
        echo [ERROR] Executable not found. Please compile first (Option 1)
        pause
        goto menu
    )
    
    mpiexec -n %num_procs% word_count_resilient.exe scripts\sample2.txt
)

echo.
pause
goto menu

:performance
echo.
echo ========================================
echo Performance Measurement
echo ========================================
echo.
echo 1. Measure Checkpoint Overhead
echo 2. Measure Recovery Time
echo 3. Measure Throughput
echo 4. Run All Performance Tests
echo 5. Back to Main Menu
echo.
set /p perf_choice="Select option (1-5): "

if "%perf_choice%"=="1" (
    if exist "scripts\measure_checkpoint_overhead.ps1" (
        powershell -ExecutionPolicy Bypass -File scripts\measure_checkpoint_overhead.ps1
    ) else (
        echo [ERROR] Script not found
    )
)

if "%perf_choice%"=="2" (
    if exist "scripts\measure_recovery_time.ps1" (
        powershell -ExecutionPolicy Bypass -File scripts\measure_recovery_time.ps1
    ) else (
        echo [ERROR] Script not found
    )
)

if "%perf_choice%"=="3" (
    if exist "scripts\measure_throughput.ps1" (
        powershell -ExecutionPolicy Bypass -File scripts\measure_throughput.ps1
    ) else (
        echo [ERROR] Script not found
    )
)

if "%perf_choice%"=="4" (
    echo Running all performance tests...
    if exist "scripts\measure_checkpoint_overhead.ps1" (
        powershell -ExecutionPolicy Bypass -File scripts\measure_checkpoint_overhead.ps1
    )
    if exist "scripts\measure_recovery_time.ps1" (
        powershell -ExecutionPolicy Bypass -File scripts\measure_recovery_time.ps1
    )
    if exist "scripts\measure_throughput.ps1" (
        powershell -ExecutionPolicy Bypass -File scripts\measure_throughput.ps1
    )
)

if "%perf_choice%"=="5" goto menu

echo.
pause
goto menu

:clean
echo.
echo ========================================
echo Cleaning Build Files...
echo ========================================
echo.

if exist "word_count_resilient.exe" (
    del word_count_resilient.exe
    echo [OK] Deleted word_count_resilient.exe
)

if exist "*.o" (
    del *.o
    echo [OK] Deleted object files
)

if exist "checkpoint_*.dat" (
    del checkpoint_*.dat
    echo [OK] Deleted checkpoint files
)

if exist "*.log" (
    del *.log
    echo [OK] Deleted log files
)

echo.
echo [OK] Cleanup completed
pause
goto menu

:end
echo.
echo ========================================
echo Exiting Phase 3 Build Script
echo ========================================
echo.
echo For more information, see:
echo   - Phase3\README.md
echo   - Phase3\TECHNICAL_REPORT.md
echo.
pause
exit /b 0
