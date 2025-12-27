# Run script for Phase3 resilient word counter
# Usage: .\run.ps1 [num_processes] [input_file]

param(
    [int]$NumProcesses = 4,
    [string]$InputFile = "sample2.txt"
)

Write-Host "========== Running Resilient Word Counter ==========" -ForegroundColor Cyan
Write-Host "Processes: $NumProcesses" -ForegroundColor Green
Write-Host "Input File: $InputFile" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if MPI is in PATH
$mpiPath = Get-Command mpiexec.exe -ErrorAction SilentlyContinue
if (-not $mpiPath) {
    Write-Host "Adding MS-MPI to PATH..." -ForegroundColor Yellow
    $env:Path += ";C:\Program Files\Microsoft MPI\Bin"
}

# Check if executable exists
if (-not (Test-Path "word_count_resilient.exe")) {
    Write-Host "Error: word_count_resilient.exe not found!" -ForegroundColor Red
    Write-Host "Please run .\compile.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Copy input file to current directory if not exists
$srcFile = "..\src\$InputFile"
if ((Test-Path $srcFile) -and -not (Test-Path $InputFile)) {
    Copy-Item $srcFile . -Force
    Write-Host "Copied $InputFile to current directory`n" -ForegroundColor Yellow
}

# Run the program
Write-Host "Starting execution...`n" -ForegroundColor Green
mpiexec -n $NumProcesses .\word_count_resilient.exe $InputFile

Write-Host "`n========== Execution Complete ==========" -ForegroundColor Cyan
