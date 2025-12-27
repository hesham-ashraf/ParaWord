# Task 18: Measure Checkpoint Overhead
# Compares execution time with checkpointing enabled vs disabled

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Task 18: Checkpoint Overhead Measurement" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$NUM_PROCESSES = 8
$NUM_RUNS = 5
$INPUT_FILE = "..\src\sample2.txt"
$RESULTS_FILE = "checkpoint_overhead_results.csv"

# Create results file with header
"Configuration,Run,ExecutionTime,Checkpoints,Overhead" | Out-File $RESULTS_FILE

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Processes: $NUM_PROCESSES"
Write-Host "  Runs per test: $NUM_RUNS"
Write-Host "  Input file: $INPUT_FILE"
Write-Host ""

# Test 1: Without checkpointing (baseline)
Write-Host "Test 1: Baseline (No Checkpointing)" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# Modify source to disable checkpointing
$sourceFile = "..\src\word_count_resilient.cpp"
$sourceBackup = "..\src\word_count_resilient.cpp.bak"
Copy-Item $sourceFile $sourceBackup

# Disable checkpointing by setting large interval
(Get-Content $sourceFile) -replace 'const int CHECKPOINT_INTERVAL = \d+;', 'const int CHECKPOINT_INTERVAL = 999999;' | Set-Content $sourceFile

# Recompile
Write-Host "Compiling without checkpointing..." -ForegroundColor Yellow
Set-Location ..\src
& mpic++ -std=c++17 -O3 -o word_count_resilient.exe word_count_resilient.cpp checkpoint.cpp -I"C:\Program Files (x86)\Microsoft SDKs\MPI\Include" -L"C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64" -lmsmpi 2>&1 | Out-Null
Copy-Item word_count_resilient.exe ..\scripts\
Set-Location ..\scripts

$baselineTimes = @()
for ($i = 1; $i -le $NUM_RUNS; $i++) {
    Write-Host "  Run $i/$NUM_RUNS..." -NoNewline
    
    # Clean checkpoints
    if (Test-Path "..\checkpoints") {
        Remove-Item "..\checkpoints\*" -Force -ErrorAction SilentlyContinue
    }
    
    $startTime = Get-Date
    & mpiexec -n $NUM_PROCESSES .\word_count_resilient.exe $INPUT_FILE 2>&1 | Out-Null
    $endTime = Get-Date
    $elapsed = ($endTime - $startTime).TotalSeconds
    
    $baselineTimes += $elapsed
    "Baseline,$i,$elapsed,0,0" | Out-File $RESULTS_FILE -Append
    
    Write-Host " $([math]::Round($elapsed, 3))s" -ForegroundColor Cyan
}

$avgBaseline = ($baselineTimes | Measure-Object -Average).Average
Write-Host "  Average: $([math]::Round($avgBaseline, 3))s" -ForegroundColor White
Write-Host ""

# Test 2: With frequent checkpointing
Write-Host "Test 2: With Checkpointing (Interval=100)" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Restore and modify for checkpointing
Copy-Item $sourceBackup $sourceFile
(Get-Content $sourceFile) -replace 'const int CHECKPOINT_INTERVAL = \d+;', 'const int CHECKPOINT_INTERVAL = 100;' | Set-Content $sourceFile

# Recompile
Write-Host "Compiling with checkpointing..." -ForegroundColor Yellow
Set-Location ..\src
& mpic++ -std=c++17 -O3 -o word_count_resilient.exe word_count_resilient.cpp checkpoint.cpp -I"C:\Program Files (x86)\Microsoft SDKs\MPI\Include" -L"C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64" -lmsmpi 2>&1 | Out-Null
Copy-Item word_count_resilient.exe ..\scripts\
Set-Location ..\scripts

$checkpointTimes = @()
for ($i = 1; $i -le $NUM_RUNS; $i++) {
    Write-Host "  Run $i/$NUM_RUNS..." -NoNewline
    
    # Clean checkpoints
    if (Test-Path "..\checkpoints") {
        Remove-Item "..\checkpoints\*" -Force -ErrorAction SilentlyContinue
    }
    
    $startTime = Get-Date
    & mpiexec -n $NUM_PROCESSES .\word_count_resilient.exe $INPUT_FILE 2>&1 | Out-Null
    $endTime = Get-Date
    $elapsed = ($endTime - $startTime).TotalSeconds
    
    # Count checkpoints
    $checkpointCount = 0
    if (Test-Path "..\checkpoints") {
        $checkpointCount = (Get-ChildItem "..\checkpoints\*.dat" -ErrorAction SilentlyContinue | Measure-Object).Count
    }
    
    $overhead = (($elapsed - $avgBaseline) / $avgBaseline) * 100
    $checkpointTimes += $elapsed
    "Checkpoint,$i,$elapsed,$checkpointCount,$overhead" | Out-File $RESULTS_FILE -Append
    
    Write-Host " $([math]::Round($elapsed, 3))s ($checkpointCount checkpoints, +$([math]::Round($overhead, 1))%)" -ForegroundColor Cyan
}

$avgCheckpoint = ($checkpointTimes | Measure-Object -Average).Average
Write-Host "  Average: $([math]::Round($avgCheckpoint, 3))s" -ForegroundColor White
Write-Host ""

# Restore original source
Copy-Item $sourceBackup $sourceFile
Remove-Item $sourceBackup

# Calculate statistics
$overheadPercent = (($avgCheckpoint - $avgBaseline) / $avgBaseline) * 100
$overheadTime = $avgCheckpoint - $avgBaseline

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Baseline (No Checkpointing):" -ForegroundColor Yellow
Write-Host "  Average: $([math]::Round($avgBaseline, 3))s"
Write-Host "  Min: $([math]::Round(($baselineTimes | Measure-Object -Minimum).Minimum, 3))s"
Write-Host "  Max: $([math]::Round(($baselineTimes | Measure-Object -Maximum).Maximum, 3))s"
Write-Host ""
Write-Host "With Checkpointing (Interval=100):" -ForegroundColor Yellow
Write-Host "  Average: $([math]::Round($avgCheckpoint, 3))s"
Write-Host "  Min: $([math]::Round(($checkpointTimes | Measure-Object -Minimum).Minimum, 3))s"
Write-Host "  Max: $([math]::Round(($checkpointTimes | Measure-Object -Maximum).Maximum, 3))s"
Write-Host ""
Write-Host "Checkpoint Overhead:" -ForegroundColor Yellow
Write-Host "  Time: +$([math]::Round($overheadTime, 3))s"
Write-Host "  Percentage: +$([math]::Round($overheadPercent, 2))%" -ForegroundColor $(if ($overheadPercent -lt 10) { "Green" } elseif ($overheadPercent -lt 25) { "Yellow" } else { "Red" })
Write-Host ""
Write-Host "Results saved to: $RESULTS_FILE" -ForegroundColor Green
Write-Host ""

# Summary for CSV
"Summary,Baseline,$avgBaseline,0,0" | Out-File $RESULTS_FILE -Append
"Summary,Checkpoint,$avgCheckpoint,N/A,$overheadPercent" | Out-File $RESULTS_FILE -Append
