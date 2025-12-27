# Fault injection test script
# This script runs the resilient word counter and randomly kills processes to test fault tolerance

param(
    [int]$NumProcesses = 6,
    [string]$InputFile = "sample2.txt",
    [int]$NumFailures = 2,
    [int]$MinDelay = 2,
    [int]$MaxDelay = 8
)

Write-Host "========== Fault Injection Test ==========" -ForegroundColor Cyan
Write-Host "Total Processes: $NumProcesses" -ForegroundColor Green
Write-Host "Input File: $InputFile" -ForegroundColor Green  
Write-Host "Planned Failures: $NumFailures" -ForegroundColor Yellow
Write-Host "Failure Delay: $MinDelay-$MaxDelay seconds" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Check prerequisites
if (-not (Test-Path "word_count_resilient.exe")) {
    Write-Host "Error: word_count_resilient.exe not found!" -ForegroundColor Red
    exit 1
}

# Start the MPI job in background
Write-Host "Starting MPI job..." -ForegroundColor Green
$job = Start-Process -FilePath "mpiexec" -ArgumentList "-n", $NumProcesses, "word_count_resilient.exe", $InputFile -PassThru -NoNewWindow

Start-Sleep -Seconds 2

# Inject failures
for ($i = 1; $i -le $NumFailures; $i++) {
    $delay = Get-Random -Minimum $MinDelay -Maximum $MaxDelay
    Write-Host "Injecting failure $i/$NumFailures in $delay seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $delay
    
    # Get all related processes
    $processes = Get-Process | Where-Object { $_.ProcessName -eq "word_count_resilient" }
    
    if ($processes.Count -gt 1) {
        # Kill a random worker (not the first one which might be master)
        $victim = $processes | Get-Random -Count 1
        Write-Host "Killing process PID $($victim.Id)..." -ForegroundColor Red
        Stop-Process -Id $victim.Id -Force
        Write-Host "Process killed!" -ForegroundColor Red
    } else {
        Write-Host "Not enough processes to kill" -ForegroundColor Yellow
    }
}

# Wait for job to complete
Write-Host "`nWaiting for job to complete..." -ForegroundColor Green
$job | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue

if ($job.HasExited) {
    Write-Host "`n========== Test Complete ==========" -ForegroundColor Cyan
    Write-Host "Exit Code: $($job.ExitCode)" -ForegroundColor $(if ($job.ExitCode -eq 0) { "Green" } else { "Red" })
} else {
    Write-Host "`nJob still running after timeout, terminating..." -ForegroundColor Yellow
    Stop-Process -Id $job.Id -Force
}

# Show checkpoint files
Write-Host "`nCheckpoint files created:" -ForegroundColor Cyan
Get-ChildItem "..\checkpoints" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor Gray
}
