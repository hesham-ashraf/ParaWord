# Checkpoint Recovery Test
Write-Host "Checkpoint Recovery Test" -ForegroundColor Cyan

cd $PSScriptRoot

Remove-Item "..\checkpoints\*" -ErrorAction SilentlyContinue

Write-Host "Phase 1: Baseline run..." -ForegroundColor Green
mpiexec -n 4 .\word_count_resilient.exe sample2.txt 2>&1 | Out-File "baseline.log"

if (Test-Path "results.txt") {
    Copy-Item "results.txt" "baseline_results.txt"
    $baseline = Get-Content "baseline_results.txt"
    Write-Host "Baseline complete" -ForegroundColor Green
} else {
    Write-Host "ERROR: Baseline failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Phase 2: Interrupted run..." -ForegroundColor Yellow
Remove-Item "results.txt" -ErrorAction SilentlyContinue

$job = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    $env:Path += ";C:\Program Files\Microsoft MPI\Bin"
    mpiexec -n 4 .\word_count_resilient.exe sample2.txt 2>&1
} -ArgumentList $PSScriptRoot

Start-Sleep -Seconds 2
Write-Host "Killing all processes..." -ForegroundColor Red
Get-Process -Name "word_count_resilient" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Receive-Job -Job $job -ErrorAction SilentlyContinue | Out-File "interrupted.log"
Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

$checkpoints = Get-ChildItem "..\checkpoints\*.dat" -ErrorAction SilentlyContinue
Write-Host "Checkpoints created: $($checkpoints.Count)" -ForegroundColor Yellow

Write-Host ""
Write-Host "Phase 3: Recovery run..." -ForegroundColor Green
mpiexec -n 4 .\word_count_resilient.exe sample2.txt 2>&1 | Tee-Object -FilePath "recovery.log"

$recovery_output = Get-Content "recovery.log"
$resumed = ($recovery_output | Select-String "Resuming from checkpoint").Count

Write-Host ""
Write-Host "Processes resumed from checkpoint: $resumed" -ForegroundColor Yellow

if (Test-Path "results.txt") {
    $recovery = Get-Content "results.txt"
    
    $baseline_words = ($baseline | Select-String "Total words: (\d+)").Matches.Groups[1].Value
    $recovery_words = ($recovery | Select-String "Total words: (\d+)").Matches.Groups[1].Value
    
    Write-Host ""
    if ($baseline_words -eq $recovery_words) {
        Write-Host "PASS: Recovery results match baseline!" -ForegroundColor Green
        Write-Host "Baseline: $baseline_words words" -ForegroundColor Gray
        Write-Host "Recovery: $recovery_words words" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Results mismatch" -ForegroundColor Red
        Write-Host "Baseline: $baseline_words" -ForegroundColor Gray
        Write-Host "Recovery: $recovery_words" -ForegroundColor Gray
    }
} else {
    Write-Host "ERROR: Recovery failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test Complete" -ForegroundColor Cyan
