/**
 * @file checkpoint.h
 * @brief Checkpoint system interface for fault-tolerant MPI word counting
 * 
 * This header defines data structures and functions for implementing a
 * checkpoint/recovery system that enables fault tolerance in distributed
 * MPI applications. The system uses binary serialization for efficient
 * storage and includes integrity validation through checksums.
 * 
 * Key Features:
 * - Binary checkpoint format for fast I/O
 * - Checksum validation for data integrity
 * - Version compatibility checking
 * - Cross-platform support (Windows/Unix)
 * 
 * @author Phase 3 Implementation
 * @date December 2025
 */

#ifndef CHECKPOINT_H
#define CHECKPOINT_H

#include <string>
#include <unordered_map>
#include <ctime>

/**
 * @struct CheckpointMetadata
 * @brief Metadata stored with each checkpoint for validation and tracking
 * 
 * This structure contains essential information about a checkpoint that
 * enables the system to validate, version, and track checkpoint files.
 */
struct CheckpointMetadata {
    int rank;              ///< MPI rank that created this checkpoint
    long long iteration;   ///< Iteration number when checkpoint was created
    long long total_words; ///< Total words processed so far
    time_t timestamp;      ///< Unix timestamp of checkpoint creation
    int version;           ///< Checkpoint format version (for compatibility)
    size_t checksum;       ///< Data integrity checksum for validation
};

/**
 * @struct CheckpointData
 * @brief Complete checkpoint state including metadata and word count data
 * 
 * This structure represents the complete state that needs to be saved
 * and restored for a process to resume execution after a failure.
 * Includes both the computation state (word counts) and processing
 * position information.
 */
struct CheckpointData {
    CheckpointMetadata metadata;                          ///< Checkpoint metadata for tracking
    std::unordered_map<std::string, int> wordCounts;      ///< Word frequency map (computation state)
    long long processed_bytes;                            ///< Total bytes processed so far
    long long start_position;                             ///< Starting position in file
    long long chunk_size;                                 ///< Size of chunk being processed
};

/**
 * @namespace Checkpoint
 * @brief Functions for checkpoint creation, restoration, and management
 * 
 * This namespace provides all necessary functions to implement a complete
 * checkpoint/recovery system for fault-tolerant distributed applications.
 */
namespace Checkpoint {
    /**
     * @brief Save current process state to a checkpoint file
     * 
     * Serializes the complete process state (word counts, metadata, position)
     * to a binary file. The checkpoint includes a checksum for validation.
     * Creates the checkpoint directory if it doesn't exist.
     * 
     * @param data The checkpoint data to save
     * @param checkpoint_dir Directory where checkpoint file will be created
     * @return true if checkpoint was saved successfully, false otherwise
     * 
     * @note Thread-safe when called with MPI_Barrier synchronization
     * @note Checkpoint files are named: checkpoint_rank{X}_iter{Y}.dat
     */
    bool saveCheckpoint(const CheckpointData& data, const std::string& checkpoint_dir = "../checkpoints");
    
    /**
     * @brief Load checkpoint from file and restore process state
     * 
     * Reads the most recent checkpoint file for the given rank and
     * deserializes it into the provided CheckpointData structure.
     * Validates the checkpoint integrity using checksums.
     * 
     * @param rank MPI rank to load checkpoint for
     * @param data Output parameter where loaded data will be stored
     * @param checkpoint_dir Directory where checkpoint files are stored
     * @return true if checkpoint was loaded and validated, false otherwise
     * 
     * @note Automatically finds the most recent checkpoint iteration
     */
    bool loadCheckpoint(int rank, CheckpointData& data, const std::string& checkpoint_dir = "../checkpoints");
    
    /**
     * @brief Check if a checkpoint file exists for the given rank
     * 
     * @param rank MPI rank to check for
     * @param checkpoint_dir Directory where checkpoint files are stored
     * @return true if at least one checkpoint file exists, false otherwise
     */
    bool checkpointExists(int rank, const std::string& checkpoint_dir = "../checkpoints");
    
    /**
     * @brief Find the most recent checkpoint file for a rank
     * 
     * Searches for checkpoint files matching the rank pattern and
     * returns the path to the checkpoint with the highest iteration number.
     * 
     * @param rank MPI rank to search for
     * @param checkpoint_dir Directory where checkpoint files are stored
     * @return Full path to the latest checkpoint file, or empty string if none found
     */
    std::string getLatestCheckpoint(int rank, const std::string& checkpoint_dir = "../checkpoints");
    
    /**
     * @brief Delete the latest checkpoint file for a rank
     * 
     * Removes the most recent checkpoint file from disk. Useful for
     * cleanup after successful completion or for testing purposes.
     * 
     * @param rank MPI rank whose checkpoint should be deleted
     * @param checkpoint_dir Directory where checkpoint files are stored
     * @return true if checkpoint was deleted, false if not found or error occurred
     */
    bool deleteCheckpoint(int rank, const std::string& checkpoint_dir = "../checkpoints");
    
    /**
     * @brief Validate checkpoint data integrity using checksums
     * 
     * Recalculates the checksum for the word count data and compares
     * it with the stored checksum. Also validates the checkpoint version.
     * 
     * @param data Checkpoint data to validate
     * @return true if checksum matches and version is supported, false otherwise
     * 
     * @note This function is automatically called by loadCheckpoint()
     */
    bool validateCheckpoint(const CheckpointData& data);
    
    /**
     * @brief Calculate checksum for word count data
     * 
     * Computes a simple additive checksum by summing ASCII values of
     * all characters in words and their counts. Used for integrity validation.
     * 
     * @param wordCounts Map of words to their counts
     * @return Checksum value as size_t
     * 
     * @note This is a simple checksum; CRC32 or MD5 would be more robust
     */
    size_t calculateChecksum(const std::unordered_map<std::string, int>& wordCounts);
}

#endif // CHECKPOINT_H
