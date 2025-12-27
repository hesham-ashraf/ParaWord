# Test script for Spark Streaming + gRPC Integration
# Phase 3 Bonus Feature

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Spark Streaming + gRPC Integration Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if setup is complete
Write-Host "Checking setup..." -ForegroundColor Yellow

$requiredFiles = @(
    "wordcount_pb2.py",
    "wordcount_pb2_grpc.py",
    "grpc_wordcount_server.py",
    "spark_streaming_app.py"
)

$setupOk = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  [OK] $file" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $file" -ForegroundColor Red
        $setupOk = $false
    }
}

if (-not $setupOk) {
    Write-Host ""
    Write-Host "Setup incomplete! Please run: .\setup.ps1" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 1: Start gRPC server
Write-Host "Test 1: Starting gRPC server..." -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

$serverJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    python grpc_wordcount_server.py --port 50051
}

Write-Host "Waiting for server to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Test 2: Health check
Write-Host ""
Write-Host "Test 2: Testing gRPC server health..." -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

$testClient = @"
import grpc
import wordcount_pb2
import wordcount_pb2_grpc

channel = grpc.insecure_channel('localhost:50051')
stub = wordcount_pb2_grpc.WordCountServiceStub(channel)
request = wordcount_pb2.HealthRequest(client_id='test')
response = stub.HealthCheck(request)
print(f'Health: {response.healthy}, Version: {response.version}')
channel.close()
"@

$testClient | Out-File -FilePath "test_client.py" -Encoding UTF8
python test_client.py

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] gRPC server is healthy" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] gRPC server health check failed" -ForegroundColor Red
}

Write-Host ""

# Test 3: Test word counting via gRPC
Write-Host "Test 3: Testing word count via gRPC..." -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

$testWordCount = @"
import grpc
import wordcount_pb2
import wordcount_pb2_grpc

channel = grpc.insecure_channel('localhost:50051')
stub = wordcount_pb2_grpc.WordCountServiceStub(channel)

text = 'hello world hello spark streaming'
request = wordcount_pb2.TextChunk(
    chunk_id='test_1',
    text=text,
    timestamp=0,
    batch_id=0
)

response = stub.CountWords(request)
print(f'Total words: {response.total_words}')
print(f'Unique words: {response.unique_words}')
print(f'Success: {response.success}')
print(f'Processing time: {response.processing_time:.4f}s')
channel.close()
"@

$testWordCount | Out-File -FilePath "test_wordcount.py" -Encoding UTF8
$output = python test_wordcount.py

Write-Host $output
if ($output -match "Success: True") {
    Write-Host "  [PASS] Word counting works correctly" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Word counting failed" -ForegroundColor Red
}

Write-Host ""

# Test 4: Start Spark Streaming (will run in background)
Write-Host "Test 4: Starting Spark Streaming application..." -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

# Clean previous output
if (Test-Path "output") {
    Remove-Item "output\*" -Force -ErrorAction SilentlyContinue
}

$sparkJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    python spark_streaming_app.py --interval "5 seconds"
}

Write-Host "Waiting for Spark to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Test 5: Add test file to trigger processing
Write-Host ""
Write-Host "Test 5: Triggering micro-batch processing..." -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

$testText = @"
This is a test file for Spark Structured Streaming.
The streaming application will read this file.
It will be processed in a micro-batch.
The gRPC service will count all the words.
This test verifies the complete integration.
"@

$testText | Out-File -FilePath "streaming_input\test_01.txt" -Encoding UTF8
Write-Host "  [OK] Added test file: streaming_input/test_01.txt" -ForegroundColor Green

Write-Host "Waiting for processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check if output was generated
if (Test-Path "output\batch_0_results.json") {
    Write-Host "  [PASS] Micro-batch processed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Results:" -ForegroundColor Yellow
    Get-Content "output\batch_0_results.json" | Write-Host
} else {
    Write-Host "  [FAIL] No output generated" -ForegroundColor Red
}

Write-Host ""

# Cleanup
Write-Host "Cleaning up..." -ForegroundColor Yellow
Stop-Job $serverJob -ErrorAction SilentlyContinue
Stop-Job $sparkJob -ErrorAction SilentlyContinue
Remove-Job $serverJob -Force -ErrorAction SilentlyContinue
Remove-Job $sparkJob -Force -ErrorAction SilentlyContinue

Remove-Item "test_client.py" -Force -ErrorAction SilentlyContinue
Remove-Item "test_wordcount.py" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Integration Test Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run manually:" -ForegroundColor Yellow
Write-Host "1. Terminal 1: python grpc_wordcount_server.py" -ForegroundColor Gray
Write-Host "2. Terminal 2: python spark_streaming_app.py" -ForegroundColor Gray
Write-Host "3. Add files: Copy-Item ..\src\sample.txt streaming_input\input.txt" -ForegroundColor Gray
Write-Host ""
