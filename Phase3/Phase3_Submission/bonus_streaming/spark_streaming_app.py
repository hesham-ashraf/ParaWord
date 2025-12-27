#!/usr/bin/env python3
"""
Spark Structured Streaming Application with gRPC Integration
Phase 3 Bonus: Micro-batch Ingestion + gRPC Calls

This application reads text data in micro-batches using Spark Structured Streaming
and makes gRPC calls to the word count service for each batch.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf, struct, lit, current_timestamp
from pyspark.sql.types import StructType, StructField, StringType, LongType, BooleanType, MapType, DoubleType
import grpc
import time
import json
import logging

# Import generated protobuf code
import wordcount_pb2
import wordcount_pb2_grpc

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class GRPCWordCountClient:
    """Client for calling gRPC word count service"""
    
    def __init__(self, host='localhost', port=50051):
        self.host = host
        self.port = port
        self.channel = None
        self.stub = None
        self.connect()
    
    def connect(self):
        """Establish connection to gRPC server"""
        try:
            self.channel = grpc.insecure_channel(f'{self.host}:{self.port}')
            self.stub = wordcount_pb2_grpc.WordCountServiceStub(self.channel)
            logger.info(f"Connected to gRPC server at {self.host}:{self.port}")
        except Exception as e:
            logger.error(f"Failed to connect to gRPC server: {e}")
            raise
    
    def count_words(self, chunk_id, text, batch_id=0):
        """
        Call gRPC service to count words
        
        Args:
            chunk_id (str): Unique identifier for this chunk
            text (str): Text content to process
            batch_id (int): Micro-batch identifier
            
        Returns:
            dict: Result containing word counts
        """
        try:
            # Create request
            request = wordcount_pb2.TextChunk(
                chunk_id=chunk_id,
                text=text,
                timestamp=int(time.time()),
                batch_id=batch_id
            )
            
            # Make gRPC call
            response = self.stub.CountWords(request)
            
            # Convert to dictionary
            result = {
                'chunk_id': response.chunk_id,
                'total_words': response.total_words,
                'unique_words': response.unique_words,
                'word_counts': dict(response.word_counts),
                'processing_time': response.processing_time,
                'success': response.success,
                'error_message': response.error_message
            }
            
            return result
            
        except Exception as e:
            logger.error(f"gRPC call failed for chunk {chunk_id}: {e}")
            return {
                'chunk_id': chunk_id,
                'total_words': 0,
                'unique_words': 0,
                'word_counts': {},
                'processing_time': 0.0,
                'success': False,
                'error_message': str(e)
            }
    
    def health_check(self):
        """Check if gRPC server is healthy"""
        try:
            request = wordcount_pb2.HealthRequest(client_id="spark_streaming")
            response = self.stub.HealthCheck(request)
            return response.healthy
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return False
    
    def close(self):
        """Close connection"""
        if self.channel:
            self.channel.close()
            logger.info("gRPC connection closed")


def process_batch_with_grpc(batch_df, batch_id, grpc_host='localhost', grpc_port=50051):
    """
    Process each micro-batch by making gRPC calls
    
    Args:
        batch_df: Spark DataFrame containing the batch
        batch_id: Batch identifier
        grpc_host: gRPC server host
        grpc_port: gRPC server port
    """
    logger.info(f"Processing batch {batch_id}")
    
    # Collect rows from this batch
    rows = batch_df.collect()
    
    if not rows:
        logger.info(f"Batch {batch_id} is empty, skipping")
        return
    
    # Create gRPC client
    client = GRPCWordCountClient(host=grpc_host, port=grpc_port)
    
    # Process each row via gRPC
    results = []
    for idx, row in enumerate(rows):
        chunk_id = f"batch_{batch_id}_chunk_{idx}"
        text = row['value']
        
        logger.info(f"Processing {chunk_id} via gRPC")
        result = client.count_words(chunk_id, text, batch_id)
        results.append(result)
        
        logger.info(
            f"  Result: {result['total_words']} words, "
            f"{result['unique_words']} unique, "
            f"success={result['success']}"
        )
    
    # Aggregate results for this batch
    total_words_batch = sum(r['total_words'] for r in results)
    total_unique_batch = sum(r['unique_words'] for r in results)
    successful_chunks = sum(1 for r in results if r['success'])
    
    logger.info(
        f"Batch {batch_id} complete: {len(results)} chunks processed, "
        f"{total_words_batch} total words, {total_unique_batch} unique words (aggregated), "
        f"{successful_chunks}/{len(results)} successful"
    )
    
    # Save batch results
    output_file = f"output/batch_{batch_id}_results.json"
    with open(output_file, 'w') as f:
        json.dump({
            'batch_id': batch_id,
            'chunks_processed': len(results),
            'total_words': total_words_batch,
            'total_unique': total_unique_batch,
            'successful_chunks': successful_chunks,
            'results': results
        }, f, indent=2)
    
    logger.info(f"Batch {batch_id} results saved to {output_file}")
    
    # Close client
    client.close()


def create_spark_streaming_app(
    input_path,
    grpc_host='localhost',
    grpc_port=50051,
    trigger_interval='10 seconds'
):
    """
    Create and run Spark Structured Streaming application
    
    Args:
        input_path (str): Path to input data (file or directory to monitor)
        grpc_host (str): gRPC server hostname
        grpc_port (int): gRPC server port
        trigger_interval (str): Micro-batch trigger interval
    """
    logger.info("Creating Spark Structured Streaming application")
    
    # Create Spark session
    spark = SparkSession.builder \
        .appName("WordCount_Streaming_gRPC") \
        .master("local[*]") \
        .config("spark.sql.streaming.schemaInference", "true") \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    
    logger.info(f"Spark session created: {spark.version}")
    logger.info(f"Input path: {input_path}")
    logger.info(f"gRPC server: {grpc_host}:{grpc_port}")
    logger.info(f"Trigger interval: {trigger_interval}")
    
    # Read streaming data from text files
    # This will monitor the input directory and process new files as they arrive
    df_stream = spark \
        .readStream \
        .format("text") \
        .option("maxFilesPerTrigger", 1) \
        .load(input_path)
    
    logger.info("Streaming DataFrame created")
    
    # Write stream with foreachBatch to process each micro-batch via gRPC
    query = df_stream \
        .writeStream \
        .foreachBatch(lambda batch_df, batch_id: 
                     process_batch_with_grpc(batch_df, batch_id, grpc_host, grpc_port)) \
        .trigger(processingTime=trigger_interval) \
        .option("checkpointLocation", "checkpoints/spark_streaming") \
        .start()
    
    logger.info("Streaming query started")
    logger.info("Waiting for data... (Press Ctrl+C to stop)")
    
    # Wait for termination
    try:
        query.awaitTermination()
    except KeyboardInterrupt:
        logger.info("Stopping streaming query...")
        query.stop()
        spark.stop()
        logger.info("Application stopped")


if __name__ == '__main__':
    import argparse
    import os
    
    parser = argparse.ArgumentParser(
        description='Spark Structured Streaming with gRPC Word Count'
    )
    parser.add_argument(
        '--input', 
        type=str, 
        default='streaming_input',
        help='Input directory to monitor for new files'
    )
    parser.add_argument(
        '--grpc-host',
        type=str,
        default='localhost',
        help='gRPC server hostname'
    )
    parser.add_argument(
        '--grpc-port',
        type=int,
        default=50051,
        help='gRPC server port'
    )
    parser.add_argument(
        '--interval',
        type=str,
        default='10 seconds',
        help='Micro-batch trigger interval'
    )
    
    args = parser.parse_args()
    
    # Create directories if they don't exist
    os.makedirs(args.input, exist_ok=True)
    os.makedirs('output', exist_ok=True)
    os.makedirs('checkpoints', exist_ok=True)
    
    # Test gRPC connection before starting
    logger.info("Testing gRPC connection...")
    try:
        client = GRPCWordCountClient(host=args.grpc_host, port=args.grpc_port)
        if client.health_check():
            logger.info("✓ gRPC server is healthy")
            client.close()
        else:
            logger.error("✗ gRPC server health check failed")
            exit(1)
    except Exception as e:
        logger.error(f"✗ Cannot connect to gRPC server: {e}")
        logger.error("Please ensure the gRPC server is running:")
        logger.error(f"  python grpc_wordcount_server.py --port {args.grpc_port}")
        exit(1)
    
    # Start streaming application
    create_spark_streaming_app(
        input_path=args.input,
        grpc_host=args.grpc_host,
        grpc_port=args.grpc_port,
        trigger_interval=args.interval
    )
