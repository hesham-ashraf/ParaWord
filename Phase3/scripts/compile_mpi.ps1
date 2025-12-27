$MPI_INCLUDE = "C:\Program Files (x86)\Microsoft SDKs\MPI\Include"
$MPI_LIB = "C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64"
$SOURCE = $args[0]
$OUTPUT = $args[1]

if (-not $SOURCE) {
    Write-Host "Usage: .\compile_mpi.ps1 <source.cpp> <output.exe>"
    exit 1
}

if (-not $OUTPUT) {
    $OUTPUT = [System.IO.Path]::GetFileNameWithoutExtension($SOURCE) + ".exe"
}

$cmd = "g++.exe -I`"$MPI_INCLUDE`" -L`"$MPI_LIB`" $SOURCE -lmsmpi -o $OUTPUT"
Write-Host "Executing: $cmd"
Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilation successful: $OUTPUT" -ForegroundColor Green
} else {
    Write-Host "Compilation failed" -ForegroundColor Red
}
