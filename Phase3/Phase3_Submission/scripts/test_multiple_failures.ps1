# Test Multiple Failures
Write-Host "Multiple Failures Test" -ForegroundColor Cyan

cd $PSScriptRoot

Remove-Item "..\checkpoints\*" -ErrorAction SilentlyContinue
Remove-Item "results.txt" -ErrorAction SilentlyContinue

Write-Host "Starting 8 processes..." -ForegroundColor Green

$job = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    $env:Path += ";C:\Program Files\Microsoft MPI\Bin"
    mpiexec -n 8 .\word_count_resilient.exe sample2.txt 2>&1
} -ArgumentList $PSScriptRoot

$failures = 0

Start-Sleep -Seconds 1
$procs = Get-Process -Name "word_count_resilient" -ErrorAction SilentlyContinue
if ($procs.Count -gt 2) {
    $victim = $procs | Select-Object -Skip 1 | Get-Random
    Write-Host "Failure 1: Killing PID $($victim.Id)" -ForegroundColor Red
    Stop-Process -Id $victim.Id -Force -ErrorAction SilentlyContinue
    $failures++
}

Start-Sleep -Seconds 2
$procs = Get-Process -Name "word_count_resilient" -ErrorAction SilentlyContinue
if ($procs.Count -gt 2) {
    $victim = $procs | Select-Object -Skip 1 | Get-Random
    Write-Host "Failure 2: Killing PID $($victim.Id)" -ForegroundColor Red
    Stop-Process -Id $victim.Id -Force -ErrorAction SilentlyContinue
    $failures++
}

Start-Sleep -Seconds 2
$procs = Get-Process -Name "word_count_resilient" -ErrorAction SilentlyContinue
if ($procs.Count -gt 2) {
    $victim = $procs | Select-Object -Skip 1 | Get-Random
    Write-Host "Failure 3: Killing PID $($victim.Id)" -ForegroundColor Red
    Stop-Process -Id $victim.Id -Force -ErrorAction SilentlyContinue
    $failures++
}

Write-Host "Waiting for completion..." -ForegroundColor Yellow
$job | Wait-Job -Timeout 60 | Out-Null

$output = Receive-Job -Job $job
Remove-Job -Job $job

$output | Out-File "test_multiple_failures.log"

Write-Host ""
$detected = ($output | Select-String "FAILURE DETECTED").Count
$reassigned = ($output | Select-String "Reassigning").Count

Write-Host "Failures Injected: $failures" -ForegroundColor Yellow
Write-Host "Failures Detected: $detected" -ForegroundColor Yellow
Write-Host "Work Reassigned: $reassigned" -ForegroundColor Yellow

if (Test-Path "results.txt") {
    $results = Get-Content "results.txt"
    Write-Host ""
    Write-Host "Final Results:" -ForegroundColor Green
    $results
    
    $words = ($results | Select-String "Total words: (\d+)").Matches.Groups[1].Value
    if ($words -eq "4000000") {
        Write-Host ""
        Write-Host "PASS: Correct word count despite failures!" -ForegroundColor Green
    }
} else {
    Write-Host "ERROR: No results produced" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test Complete" -ForegroundColor Cyan
