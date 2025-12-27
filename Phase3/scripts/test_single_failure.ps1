# Single Process Failure Test
Write-Host "========== Single Process Failure Test ==========" -ForegroundColor Cyan

cd $PSScriptRoot

if (-not (Test-Path "word_count_resilient.exe")) {
    Write-Host "Executable not found!" -ForegroundColor Red
    exit 1
}

# Clean up
Remove-Item "..\checkpoints\*" -ErrorAction SilentlyContinue
Remove-Item "results.txt" -ErrorAction SilentlyContinue

Write-Host "Running baseline test..." -ForegroundColor Green
$baseline_start = Get-Date
mpiexec -n 6 .\word_count_resilient.exe sample2.txt 2>&1 | Out-File "test_baseline.log"
$baseline_end = Get-Date
$baseline_time = ($baseline_end - $baseline_start).TotalSeconds

Copy-Item "results.txt" "results_baseline.txt"
$baseline_results = Get-Content "results_baseline.txt"
Write-Host "Baseline: $baseline_time seconds" -ForegroundColor Green

# Test with failure
Remove-Item "..\checkpoints\*" -ErrorAction SilentlyContinue
Remove-Item "results.txt" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Starting test with failure injection..." -ForegroundColor Yellow

$job = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    $env:Path += ";C:\Program Files\Microsoft MPI\Bin"
    mpiexec -n 6 .\word_count_resilient.exe sample2.txt 2>&1
} -ArgumentList $PSScriptRoot

Start-Sleep -Seconds 1

$processes = Get-Process -Name "word_count_resilient" -ErrorAction SilentlyContinue
if ($processes.Count -gt 1) {
    $victim = $processes | Select-Object -Skip 1 | Get-Random
    Write-Host "Killing PID $($victim.Id)..." -ForegroundColor Red
    Stop-Process -Id $victim.Id -Force
}

$failure_start = Get-Date
$job | Wait-Job -Timeout 30 | Out-Null
$failure_end = Get-Date
$failure_time = ($failure_end - $failure_start).TotalSeconds

$output = Receive-Job -Job $job
Remove-Job -Job $job

$output | Out-File "test_single_failure.log"

Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
$output | Select-String "FAILURE DETECTED|Reassigning|RESULTS" -Context 0,3

if (Test-Path "results.txt") {
    $failure_results = Get-Content "results.txt"
    
    $baseline_words = ($baseline_results | Select-String "Total words: (\d+)").Matches.Groups[1].Value
    $failure_words = ($failure_results | Select-String "Total words: (\d+)").Matches.Groups[1].Value
    
    Write-Host ""
    if ($baseline_words -eq $failure_words) {
        Write-Host "PASS: Results match ($baseline_words words)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Mismatch! $baseline_words vs $failure_words" -ForegroundColor Red
    }
    
    Write-Host "Time: $failure_time seconds (overhead: $([Math]::Round(($failure_time - $baseline_time) * 100 / $baseline_time, 1))%)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test complete!" -ForegroundColor Cyan
