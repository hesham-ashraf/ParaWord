# Task 19: Measure Recovery Time
# Measures time from failure detection to full recovery

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Task 19: Recovery Time Measurement" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$NUM_PROCESSES = 8
$NUM_RUNS = 5
$INPUT_FILE = "..\src\sample2.txt"
$RESULTS_FILE = "recovery_time_results.csv"
$FAILURE_TIMES = @(0.5, 1.0, 1.5, 2.0)  # Kill worker at different times

# Create results file
"Run,FailureTime,ProcessesKilled,DetectionTime,RecoveryTime,TotalTime,Correct" | Out-File $RESULTS_FILE

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Processes: $NUM_PROCESSES"
Write-Host "  Runs per test: $NUM_RUNS"
Write-Host "  Input file: $INPUT_FILE"
Write-Host "  Failure injection times: $($FAILURE_TIMES -join ', ')s"
Write-Host ""

# Ensure checkpointing is enabled
$sourceFile = "..\src\word_count_resilient.cpp"
$sourceBackup = "..\src\word_count_resilient.cpp.bak"
Copy-Item $sourceFile $sourceBackup

(Get-Content $sourceFile) -replace 'const int CHECKPOINT_INTERVAL = \d+;', 'const int CHECKPOINT_INTERVAL = 100;' | Set-Content $sourceFile

Write-Host "Compiling with checkpointing enabled..." -ForegroundColor Yellow
Set-Location ..\src
& mpic++ -std=c++17 -O3 -o word_count_resilient.exe word_count_resilient.cpp checkpoint.cpp -I"C:\Program Files (x86)\Microsoft SDKs\MPI\Include" -L"C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64" -lmsmpi 2>&1 | Out-Null
Copy-Item word_count_resilient.exe ..\scripts\
Set-Location ..\scripts
Write-Host ""

foreach ($failureTime in $FAILURE_TIMES) {
    Write-Host "Testing failure at T=$($failureTime)s" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    
    for ($run = 1; $run -le $NUM_RUNS; $run++) {
        Write-Host "  Run $run/$NUM_RUNS..." -NoNewline
        
        # Clean checkpoints and logs
        if (Test-Path "..\checkpoints") {
            Remove-Item "..\checkpoints\*" -Force -ErrorAction SilentlyContinue
        }
        
        $logFile = "recovery_test_$($failureTime)_$run.log"
        
        # Start the job
        $job = Start-Job -ScriptBlock {
            param($procs, $input, $log)
            Set-Location $using:PWD
            & mpiexec -n $procs .\word_count_resilient.exe $input 2>&1 | Out-File $log
        } -ArgumentList $NUM_PROCESSES, $INPUT_FILE, $logFile
        
        $startTime = Get-Date
        
        # Wait for failure injection time
        Start-Sleep -Seconds $failureTime
        
        # Kill one worker process (not master, not last)
        $workerPID = Get-Process | Where-Object { $_.ProcessName -eq "word_count_resilient" } | Select-Object -Skip 1 -First 1
        if ($workerPID) {
            $killTime = Get-Date
            Stop-Process -Id $workerPID.Id -Force -ErrorAction SilentlyContinue
            $processesKilled = 1
        } else {
            $processesKilled = 0
        }
        
        # Wait for job to complete
        Wait-Job $job -Timeout 30 | Out-Null
        $endTime = Get-Date
        
        # Calculate times
        $totalTime = ($endTime - $startTime).TotalSeconds
        $detectionTime = "N/A"
        $recoveryTime = "N/A"
        
        # Parse log for timing info
        if (Test-Path $logFile) {
            $logContent = Get-Content $logFile
            
            # Look for failure detection
            $failureLines = $logContent | Select-String "Worker.*failed" -AllMatches
            if ($failureLines) {
                $detectionTime = ($killTime - $startTime).TotalSeconds
            }
            
            # Look for work redistribution
            $redistributeLines = $logContent | Select-String "Redistributing.*work" -AllMatches
            if ($redistributeLines) {
                $recoveryTime = $totalTime - $detectionTime
            }
        }
        
        # Check correctness
        $correct = "Unknown"
        if (Test-Path "results.txt") {
            $results = Get-Content "results.txt"
            $wordCount = ($results | Select-String "Total words:.*(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
            if ($wordCount -eq "4000000") {
                $correct = "Yes"
            } else {
                $correct = "No"
            }
        }
        
        "$run,$failureTime,$processesKilled,$detectionTime,$recoveryTime,$totalTime,$correct" | Out-File $RESULTS_FILE -Append
        
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        
        Write-Host " Total: $([math]::Round($totalTime, 2))s, Correct: $correct" -ForegroundColor $(if ($correct -eq "Yes") { "Green" } else { "Yellow" })
    }
    Write-Host ""
}

# Restore original source
Copy-Item $sourceBackup $sourceFile
Remove-Item $sourceBackup

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results = Import-Csv $RESULTS_FILE
$successRate = ($results | Where-Object { $_.Correct -eq "Yes" } | Measure-Object).Count / $results.Count * 100

Write-Host "Total tests: $($results.Count)"
Write-Host "Success rate: $([math]::Round($successRate, 1))%"
Write-Host ""
Write-Host "Results saved to: $RESULTS_FILE" -ForegroundColor Green
Write-Host ""
