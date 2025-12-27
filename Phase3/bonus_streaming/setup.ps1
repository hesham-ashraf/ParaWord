# Setup script for Spark Streaming + gRPC Integration
# Phase 3 Bonus Feature

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 3 Bonus: Spark Streaming Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Install Python dependencies
Write-Host "Step 1: Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to install dependencies" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Generate gRPC code from proto file
Write-Host "Step 2: Generating gRPC code from .proto file..." -ForegroundColor Yellow
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. wordcount.proto

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Generated wordcount_pb2.py" -ForegroundColor Green
    Write-Host "  [OK] Generated wordcount_pb2_grpc.py" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to generate gRPC code" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: Create necessary directories
Write-Host "Step 3: Creating directories..." -ForegroundColor Yellow
$dirs = @("streaming_input", "output", "checkpoints", "logs")
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "  [OK] Created $dir/" -ForegroundColor Green
    } else {
        Write-Host "  [OK] $dir/ already exists" -ForegroundColor Gray
    }
}
Write-Host ""

# Step 4: Create sample input file
Write-Host "Step 4: Creating sample input file..." -ForegroundColor Yellow
$sampleText = @"
The quick brown fox jumps over the lazy dog.
This is a sample text file for testing Spark Structured Streaming.
The streaming application will process this text in micro-batches.
Each micro-batch will be sent to the gRPC word count service.
The gRPC service will count the words and return the results.
This demonstrates the integration of Spark Streaming with gRPC.
"@

$sampleText | Out-File -FilePath "streaming_input\sample_00.txt" -Encoding UTF8
Write-Host "  [OK] Created streaming_input/sample_00.txt" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Start gRPC server:" -ForegroundColor White
Write-Host "   python grpc_wordcount_server.py" -ForegroundColor Gray
Write-Host ""
Write-Host "2. In another terminal, start Spark Streaming:" -ForegroundColor White
Write-Host "   python spark_streaming_app.py" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Add files to streaming_input/ to trigger processing:" -ForegroundColor White
Write-Host "   Copy-Item ..\src\sample.txt streaming_input\input_01.txt" -ForegroundColor Gray
Write-Host ""
