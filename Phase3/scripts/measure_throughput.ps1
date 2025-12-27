# Task 20: Measure Throughput with Failures
# Compares throughput with 0, 1, 2, 3 failures

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Task 20: Throughput with Failures" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$NUM_PROCESSES = 8
$NUM_RUNS = 5
$INPUT_FILE = "..\src\sample2.txt"
$RESULTS_FILE = "throughput_results.csv"
$FILE_SIZE_MB = 24  # sample2.txt size

# Create results file
"Scenario,Run,ExecutionTime,Throughput_MBps,WordCount,Correct" | Out-File $RESULTS_FILE

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Processes: $NUM_PROCESSES"
Write-Host "  Runs per test: $NUM_RUNS"
Write-Host "  Input file: $INPUT_FILE ($FILE_SIZE_MB MB)"
Write-Host ""

# Ensure checkpointing is enabled
$sourceFile = "..\src\word_count_resilient.cpp"
$sourceBackup = "..\src\word_count_resilient.cpp.bak"
Copy-Item $sourceFile $sourceBackup

(Get-Content $sourceFile) -replace 'const int CHECKPOINT_INTERVAL = \d+;', 'const int CHECKPOINT_INTERVAL = 100;' | Set-Content $sourceFile

Write-Host "Compiling..." -ForegroundColor Yellow
Set-Location ..\src
& mpic++ -std=c++17 -O3 -o word_count_resilient.exe word_count_resilient.cpp checkpoint.cpp -I"C:\Program Files (x86)\Microsoft SDKs\MPI\Include" -L"C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64" -lmsmpi 2>&1 | Out-Null
Copy-Item word_count_resilient.exe ..\scripts\
Set-Location ..\scripts
Write-Host ""

# Test scenarios
$scenarios = @(
    @{Name="Baseline"; Failures=0},
    @{Name="1 Failure"; Failures=1},
    @{Name="2 Failures"; Failures=2},
    @{Name="3 Failures"; Failures=3}
)

foreach ($scenario in $scenarios) {
    Write-Host "Scenario: $($scenario.Name)" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    
    for ($run = 1; $run -le $NUM_RUNS; $run++) {
        Write-Host "  Run $run/$NUM_RUNS..." -NoNewline
        
        # Clean checkpoints
        if (Test-Path "..\checkpoints") {
            Remove-Item "..\checkpoints\*" -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "results.txt") {
            Remove-Item "results.txt" -Force
        }
        
        if ($scenario.Failures -eq 0) {
            # No failures - baseline
            $startTime = Get-Date
            & mpiexec -n $NUM_PROCESSES .\word_count_resilient.exe $INPUT_FILE 2>&1 | Out-Null
            $endTime = Get-Date
            $elapsed = ($endTime - $startTime).TotalSeconds
        } else {
            # With failures
            $job = Start-Job -ScriptBlock {
                param($procs, $input)
                Set-Location $using:PWD
                & mpiexec -n $procs .\word_count_resilient.exe $input 2>&1 | Out-Null
            } -ArgumentList $NUM_PROCESSES, $INPUT_FILE
            
            $startTime = Get-Date
            
            # Inject failures at different times
            for ($f = 0; $f -lt $scenario.Failures; $f++) {
                $killTime = 0.5 + ($f * 0.5)
                Start-Sleep -Seconds $killTime
                
                $workers = Get-Process | Where-Object { $_.ProcessName -eq "word_count_resilient" } | Select-Object -Skip 1
                if ($workers -and ($workers.Count -gt 0)) {
                    $targetIndex = [Math]::Min($f, $workers.Count - 1)
                    Stop-Process -Id $workers[$targetIndex].Id -Force -ErrorAction SilentlyContinue
                }
            }
            
            Wait-Job $job -Timeout 30 | Out-Null
            $endTime = Get-Date
            $elapsed = ($endTime - $startTime).TotalSeconds
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }
        
        # Calculate throughput
        $throughput = $FILE_SIZE_MB / $elapsed
        
        # Check correctness
        $wordCount = 0
        $correct = "No"
        if (Test-Path "results.txt") {
            $results = Get-Content "results.txt"
            $wordCountMatch = $results | Select-String "Total words:.*?(\d+)"
            if ($wordCountMatch) {
                $wordCount = [int]$wordCountMatch.Matches.Groups[1].Value
                if ($wordCount -eq 4000000) {
                    $correct = "Yes"
                }
            }
        }
        
        "$($scenario.Name),$run,$elapsed,$throughput,$wordCount,$correct" | Out-File $RESULTS_FILE -Append
        
        Write-Host " $([math]::Round($elapsed, 2))s, $([math]::Round($throughput, 2)) MB/s, $correct" -ForegroundColor $(if ($correct -eq "Yes") { "Green" } else { "Yellow" })
    }
    Write-Host ""
}

# Restore original source
Copy-Item $sourceBackup $sourceFile
Remove-Item $sourceBackup

# Calculate summary statistics
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results = Import-Csv $RESULTS_FILE

foreach ($scenario in $scenarios) {
    $scenarioResults = $results | Where-Object { $_.Scenario -eq $scenario.Name }
    $avgTime = ($scenarioResults | Measure-Object -Property ExecutionTime -Average).Average
    $avgThroughput = ($scenarioResults | Measure-Object -Property Throughput_MBps -Average).Average
    $successCount = ($scenarioResults | Where-Object { $_.Correct -eq "Yes" } | Measure-Object).Count
    
    Write-Host "$($scenario.Name):" -ForegroundColor Yellow
    Write-Host "  Avg Time: $([math]::Round($avgTime, 3))s"
    Write-Host "  Avg Throughput: $([math]::Round($avgThroughput, 2)) MB/s"
    Write-Host "  Success Rate: $successCount/$NUM_RUNS"
    Write-Host ""
}

# Calculate degradation
$baselineResults = $results | Where-Object { $_.Scenario -eq "Baseline" }
$baselineThroughput = ($baselineResults | Measure-Object -Property Throughput_MBps -Average).Average

Write-Host "Throughput Degradation:" -ForegroundColor Yellow
foreach ($scenario in $scenarios | Where-Object { $_.Failures -gt 0 }) {
    $scenarioResults = $results | Where-Object { $_.Scenario -eq $scenario.Name }
    $avgThroughput = ($scenarioResults | Measure-Object -Property Throughput_MBps -Average).Average
    $degradation = (($baselineThroughput - $avgThroughput) / $baselineThroughput) * 100
    
    Write-Host "  $($scenario.Name): -$([math]::Round($degradation, 1))%"
}
Write-Host ""
Write-Host "Results saved to: $RESULTS_FILE" -ForegroundColor Green
Write-Host ""
