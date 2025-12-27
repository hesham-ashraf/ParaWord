"""
Simple test script for gRPC Word Count Server
Tests the gRPC server functionality without requiring Spark
"""

import grpc
import time
import sys
from datetime import datetime

# Import generated protobuf classes
import wordcount_pb2
import wordcount_pb2_grpc


def test_health_check(channel):
    """Test the health check endpoint"""
    print("\n" + "="*60)
    print("Test 1: Health Check")
    print("="*60)
    
    try:
        stub = wordcount_pb2_grpc.WordCountServiceStub(channel)
        request = wordcount_pb2.HealthRequest()
        response = stub.HealthCheck(request)
        
        print(f"✓ Health Check: {response.status}")
        print(f"  Server healthy: {response.healthy}")
        return response.healthy
    except Exception as e:
        print(f"✗ Health Check Failed: {e}")
        return False


def test_count_words_simple(channel):
    """Test simple word counting"""
    print("\n" + "="*60)
    print("Test 2: Simple Word Counting")
    print("="*60)
    
    test_text = "Hello world! This is a test. Hello again world."
    print(f"Input text: '{test_text}'")
    
    try:
        stub = wordcount_pb2_grpc.WordCountServiceStub(channel)
        request = wordcount_pb2.TextChunk(
            chunk_id="test-001",
            text=test_text,
            timestamp=int(time.time() * 1000),
            batch_id=1
        )
        
        response = stub.CountWords(request)
        
        if response.success:
            print(f"✓ Word Count Successful")
            print(f"  Total words: {response.total_words}")
            print(f"  Unique words: {response.unique_words}")
            print(f"  Processing time: {response.processing_time:.4f} seconds")
            print(f"  Top 5 words:")
            
            # Sort word counts and display top 5
            sorted_words = sorted(
                response.word_counts.items(),
                key=lambda x: x[1],
                reverse=True
            )
            for word, count in sorted_words[:5]:
                print(f"    - '{word}': {count}")
            
            return True
        else:
            print(f"✗ Word Count Failed: {response.error_message}")
            return False
            
    except Exception as e:
        print(f"✗ Test Failed: {e}")
        return False


def test_count_words_large(channel):
    """Test with larger text"""
    print("\n" + "="*60)
    print("Test 3: Large Text Processing")
    print("="*60)
    
    # Generate a larger test text
    test_text = " ".join([
        "parallel computing distributed systems high performance",
        "parallel processing concurrent execution synchronization",
        "distributed memory shared memory message passing interface",
        "parallel algorithms scalability performance optimization"
    ] * 100)  # Repeat 100 times for larger text
    
    print(f"Input size: {len(test_text)} characters")
    print(f"Estimated words: ~{len(test_text.split())}")
    
    try:
        stub = wordcount_pb2_grpc.WordCountServiceStub(channel)
        request = wordcount_pb2.TextChunk(
            chunk_id="test-large-001",
            text=test_text,
            timestamp=int(time.time() * 1000),
            batch_id=2
        )
        
        start_time = time.time()
        response = stub.CountWords(request)
        elapsed = time.time() - start_time
        
        if response.success:
            print(f"✓ Large Text Count Successful")
            print(f"  Total words: {response.total_words}")
            print(f"  Unique words: {response.unique_words}")
            print(f"  Server processing time: {response.processing_time:.4f} seconds")
            print(f"  Total request time: {elapsed:.4f} seconds")
            print(f"  Throughput: {response.total_words/elapsed:.0f} words/second")
            
            # Display word distribution
            print(f"  Most common words:")
            sorted_words = sorted(
                response.word_counts.items(),
                key=lambda x: x[1],
                reverse=True
            )
            for word, count in sorted_words[:10]:
                print(f"    - '{word}': {count}")
            
            return True
        else:
            print(f"✗ Large Text Count Failed: {response.error_message}")
            return False
            
    except Exception as e:
        print(f"✗ Test Failed: {e}")
        return False


def test_stream_processing(channel):
    """Test streaming word count"""
    print("\n" + "="*60)
    print("Test 4: Streaming Processing")
    print("="*60)
    
    # Create multiple text chunks
    chunks = [
        "The quick brown fox jumps over the lazy dog",
        "Pack my box with five dozen liquor jugs",
        "How vexingly quick daft zebras jump",
        "The five boxing wizards jump quickly"
    ]
    
    print(f"Sending {len(chunks)} text chunks via streaming...")
    
    try:
        stub = wordcount_pb2_grpc.WordCountServiceStub(channel)
        
        # Create generator for requests
        def request_generator():
            for i, chunk_text in enumerate(chunks):
                yield wordcount_pb2.TextChunk(
                    chunk_id=f"stream-{i+1}",
                    text=chunk_text,
                    timestamp=int(time.time() * 1000),
                    batch_id=3
                )
        
        response = stub.CountWordsStream(request_generator())
        
        if response.success:
            print(f"✓ Stream Processing Successful")
            print(f"  Total words across all chunks: {response.total_words}")
            print(f"  Unique words: {response.unique_words}")
            print(f"  Processing time: {response.processing_time:.4f} seconds")
            print(f"  Combined word counts:")
            
            sorted_words = sorted(
                response.word_counts.items(),
                key=lambda x: x[1],
                reverse=True
            )
            for word, count in sorted_words[:10]:
                print(f"    - '{word}': {count}")
            
            return True
        else:
            print(f"✗ Stream Processing Failed: {response.error_message}")
            return False
            
    except Exception as e:
        print(f"✗ Test Failed: {e}")
        return False


def test_file_processing(channel):
    """Test processing actual files"""
    print("\n" + "="*60)
    print("Test 5: File Processing")
    print("="*60)
    
    # Try to read sample files from Phase3/src
    import os
    sample_files = [
        "../src/sample.txt",
        "../src/sample2.txt"
    ]
    
    for file_path in sample_files:
        if not os.path.exists(file_path):
            print(f"⊗ File not found: {file_path}")
            continue
            
        print(f"\nProcessing: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                text = f.read()
            
            file_size = len(text)
            print(f"  File size: {file_size:,} bytes")
            
            stub = wordcount_pb2_grpc.WordCountServiceStub(channel)
            request = wordcount_pb2.TextChunk(
                chunk_id=f"file-{os.path.basename(file_path)}",
                text=text,
                timestamp=int(time.time() * 1000),
                batch_id=4
            )
            
            start_time = time.time()
            response = stub.CountWords(request)
            elapsed = time.time() - start_time
            
            if response.success:
                print(f"  ✓ Processing successful")
                print(f"    Total words: {response.total_words:,}")
                print(f"    Unique words: {response.unique_words:,}")
                print(f"    Processing time: {response.processing_time:.4f} seconds")
                print(f"    Total time: {elapsed:.4f} seconds")
                print(f"    Throughput: {file_size/elapsed/1024:.2f} KB/s")
            else:
                print(f"  ✗ Processing failed: {response.error_message}")
                
        except Exception as e:
            print(f"  ✗ Error: {e}")
    
    return True


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("gRPC Word Count Server Test Suite")
    print("="*60)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Connect to server
    server_address = 'localhost:50051'
    print(f"\nConnecting to gRPC server at {server_address}...")
    
    try:
        channel = grpc.insecure_channel(server_address)
        
        # Wait for channel to be ready (with timeout)
        grpc.channel_ready_future(channel).result(timeout=10)
        print("✓ Connected to server")
        
        # Run tests
        results = []
        results.append(("Health Check", test_health_check(channel)))
        results.append(("Simple Word Count", test_count_words_simple(channel)))
        results.append(("Large Text Processing", test_count_words_large(channel)))
        results.append(("Stream Processing", test_stream_processing(channel)))
        results.append(("File Processing", test_file_processing(channel)))
        
        # Summary
        print("\n" + "="*60)
        print("Test Summary")
        print("="*60)
        
        passed = sum(1 for _, result in results if result)
        total = len(results)
        
        for test_name, result in results:
            status = "✓ PASSED" if result else "✗ FAILED"
            print(f"  {test_name}: {status}")
        
        print(f"\nTotal: {passed}/{total} tests passed")
        print(f"Success rate: {passed/total*100:.1f}%")
        
        channel.close()
        
        print(f"\nCompleted at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        return 0 if passed == total else 1
        
    except grpc.FutureTimeoutError:
        print("✗ Failed to connect: Server not responding (timeout)")
        print("\nPlease make sure the gRPC server is running:")
        print("  python grpc_wordcount_server.py")
        return 1
        
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        print("\nPlease make sure the gRPC server is running:")
        print("  python grpc_wordcount_server.py")
        return 1


if __name__ == "__main__":
    sys.exit(main())
