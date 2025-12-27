# Compilation script for Phase3 resilient word counter
# Usage: .\compile.ps1

Write-Host "========== Compiling Phase3 Resilient Word Counter ==========" -ForegroundColor Cyan

$MPI_INCLUDE = "C:\Program Files (x86)\Microsoft SDKs\MPI\Include"
$MPI_LIB = "C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64"
$SRC_DIR = "..\src"
$OUTPUT = "word_count_resilient.exe"

# Check if MinGW is in PATH
$gppPath = Get-Command g++.exe -ErrorAction SilentlyContinue
if (-not $gppPath) {
    Write-Host "Adding MinGW to PATH..." -ForegroundColor Yellow
    $env:Path += ";C:\msys64\mingw64\bin"
}

# Check if MPI is in PATH
$mpiPath = Get-Command mpiexec.exe -ErrorAction SilentlyContinue
if (-not $mpiPath) {
    Write-Host "Adding MS-MPI to PATH..." -ForegroundColor Yellow
    $env:Path += ";C:\Program Files\Microsoft MPI\Bin"
}

Write-Host "Compiling checkpoint.cpp..." -ForegroundColor Green
$cmd1 = "g++.exe -c -I`"$MPI_INCLUDE`" $SRC_DIR\checkpoint.cpp -o checkpoint.o"
Write-Host $cmd1
Invoke-Expression $cmd1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation of checkpoint.cpp failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nCompiling word_count_resilient.cpp..." -ForegroundColor Green
$cmd2 = "g++.exe -c -I`"$MPI_INCLUDE`" $SRC_DIR\word_count_resilient.cpp -o word_count_resilient.o"
Write-Host $cmd2
Invoke-Expression $cmd2

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation of word_count_resilient.cpp failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nLinking..." -ForegroundColor Green
$cmd3 = "g++.exe -L`"$MPI_LIB`" checkpoint.o word_count_resilient.o -lmsmpi -o $OUTPUT"
Write-Host $cmd3
Invoke-Expression $cmd3

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========== Compilation Successful! ==========" -ForegroundColor Green
    Write-Host "Output: $OUTPUT" -ForegroundColor Cyan
    Write-Host "`nTo run:" -ForegroundColor Yellow
    Write-Host "  mpiexec -n 4 .\$OUTPUT" -ForegroundColor White
    Write-Host "  mpiexec -n 4 .\$OUTPUT sample2.txt" -ForegroundColor White
} else {
    Write-Host "`nLinking failed!" -ForegroundColor Red
    exit 1
}
