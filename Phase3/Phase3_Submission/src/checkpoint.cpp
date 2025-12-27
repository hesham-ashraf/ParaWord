/**
 * @file checkpoint.cpp
 * @brief Implementation of checkpoint system for fault-tolerant MPI applications
 * 
 * This file implements binary serialization and deserialization of checkpoint
 * data, enabling processes to save their state and recover from failures.
 * 
 * Binary Format:
 * - CheckpointMetadata (fixed size)
 * - processed_bytes, start_position, chunk_size (3 x long long)
 * - map_size (size_t)
 * - For each word: word_length (size_t), word_data (bytes), count (int)
 * 
 * @author Phase 3 Implementation
 * @date December 2025
 */

#include "checkpoint.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <iomanip>
#ifdef _WIN32
    #include <direct.h>   // For _mkdir on Windows
#else
    #include <sys/stat.h> // For mkdir on Unix/Linux
#endif

using namespace std;

namespace Checkpoint {

/**
 * @brief Calculate simple additive checksum for data integrity validation
 * 
 * This function computes a checksum by summing the ASCII values of all
 * characters in the words plus their counts. While simple, it provides
 * basic protection against data corruption.
 * 
 * Algorithm: checksum = Σ(ASCII(char) + word_count)
 * 
 * @param wordCounts Map of words to their frequency counts
 * @return Checksum value that can be stored and verified later
 */
size_t calculateChecksum(const unordered_map<string, int>& wordCounts) {
    size_t checksum = 0;
    
    // Sum ASCII values of all characters plus their counts
    for (const auto& pair : wordCounts) {
        for (char c : pair.first) {
            checksum += static_cast<size_t>(c);
        }
        checksum += pair.second;
    }
    
    return checksum;
}
// Check 1: Validate checksum for data integrity
    size_t calculated = calculateChecksum(data.wordCounts);
    if (calculated != data.metadata.checksum) {
        cerr << "[Checkpoint] Validation failed: checksum mismatch "
             << "(expected " << data.metadata.checksum << ", got " << calculated << ")\n";
        return false;
    }
    
    // Check 2: Verify version compatibility
    if (data.metadata.version != 1) {
        cerr << "[Checkpoint] Validation failed: unsupported version " 
             << data.metadata.version << " (expected 1)\n";
        return false;
    }
    
    return true;
}

/**
 * @brief Save complete process state to a binary checkpoint file
 * 
 * This function creates a checkpoint file containing all necessary state
 * for a process to resume execution after a failure. The file format is
 * binary for efficient I/O and includes a checksum for validation.
 * 
 * File Format (binary):
 * 1. CStep 1: Create checkpoint directory if it doesn't exist
    // Platform-specific directory creation
    #ifdef _WIN32
        _mkdir(checkpoint_dir.c_str());  // Windows API
    #else
        mkdir(checkpoint_dir.c_str(), 0755);  // Unix/Linux with permissions
    #endif
    
    // Step 2: Generate unique checkpoint filename based on rank and iteration
    ostringstream filename;
    filename << checkpoint_dir << "/checkpoint_rank" << data.metadata.rank 
             << "_iter" << data.metadata.iteration << ".dat";
    
    // Step 3: Open file in binary write mode
    ofstream file(filename.str(), ios::binary);
    if (!file.is_open()) {
        cerr << "[Checkpoint] Failed to create checkpoint file: " << filename.str() << "\n";
        return false;
    }
    
    // Step 4: Write metadata (fixed-size struct)
    file.write(reinterpret_cast<const char*>(&data.metadata), sizeof(CheckpointMetadata));
    
    // Step 5: Write chunk/position information for resuming processing
    file.write(reinterpret_cast<const char*>(&data.processed_bytes), sizeof(long long));
    file.write(reinterpret_cast<const char*>(&data.start_position), sizeof(long long));
    file.write(reinterpret_cast<const char*>(&data.chunk_size), sizeof(long long));
    
    // Step 6: Write word count map
    // First write the number of entries
    size_t map_size = data.wordCounts.size();
    file.write(reinterpret_cast<const char*>(&map_size), sizeof(size_t));
    
    // Then write each word-count pair
    for (const auto& pair : data.wordCounts) {
        // Write word length, then word data, then count
    #else
        mkdir(checkpoint_dir.c_str(), 0755);
    #endif
    
    // Generate checkpoint filename
    ostringstream filename;
    filename << checkpoint_dir << "/checkpoint_rank" << data.metadata.rank 
             << "_iter" << data.metadata.iteration << ".dat";
    
    ofstream file(filename.str(), ios::binary);
    if (!file.is_open()) {
        cerr << "[Checkpoint] Failed to create checkpoint file: " << filename.str() << "\n";
        return false;
    }
    
    // Write metadata
    file.write(reinterpret_cast<const char*>(&data.metadata), sizeof(CheckpointMetadata));
    
    // Write chunk information
    file.write(reinterpret_cast<const char*>(&data.processed_bytes), sizeof(long long));
    file.write(reinterpret_cast<const char*>(&data.start_position), sizeof(long long));
    file.write(reinterpret_cast<const char*>(&data.chunk_size), sizeof(long long));
    
    // Write word count map size
    size_t map_size = data.wordCounts.size();
    file.write(reinterpret_cast<const char*>(&map_size), sizeof(size_t));
    
    // Write each word-count pair
    for (const auto& pair : data.wordCounts) {
        size_t word_len = pair.first.length();
        file.write(reinterpret_cast<const char*>(&word_len), sizeof(size_t));
        file.write(pair.first.c_str(), word_len);
        file.write(reinterpret_cast<const char*>(&pair.second), sizeof(int));
    // Log success message with statistics
    cout << "[Checkpoint] Rank " << data.metadata.rank << " saved checkpoint at iteration " 
         << data.metadata.iteration << " (" << data.wordCounts.size() << " unique words)\n";
    
    return true;
}

/**
 * @// Step 1: Find the most recent checkpoint file for this rank
    string filename = getLatestCheckpoint(rank, checkpoint_dir);
    if (filename.empty()) {
        // No checkpoint found - this is not an error, just means fresh start
        return false;
    }
    
    // Step 2: Open checkpoint file in binary read mode
    ifstream file(filename, ios::binary);
    if (!file.is_open()) {
        cerr << "[Checkpoint] Failed to open checkpoint file: " << filename << "\n";
        return false;
    }
    
    // Step 3: Read metadata (fixed-size struct)
    file.read(reinterpret_cast<char*>(&data.metadata), sizeof(CheckpointMetadata));
    
    // Step 4: Read chunk/position information
    file.read(reinterpret_cast<char*>(&data.processed_bytes), sizeof(long long));
    file.read(reinterpret_cast<char*>(&data.start_position), sizeof(long long));
    file.read(reinterpret_cast<char*>(&data.chunk_size), sizeof(long long));
    
    // Step 5: Read word count map
    // First read the number of entries
    size_t map_size;
    file.read(reinterpret_cast<char*>(&map_size), sizeof(size_t));
    
    // Clear any existing data and read each word-count pair
    data.wordCounts.clear();
    for (size_t i = 0; i < map_size; ++i) {
        // Read word length
        size_t word_len;
        file.read(reinterpret_cast<char*>(&word_len), sizeof(size_t));
        
        // Read word data
        string word(word_len, '\0');
        file.read(&word[0], word_len);
        
        // Read count
        int count;
        file.read(reinterpret_cast<char*>(&count), sizeof(int));
        
        // Store in map
    
    // Step 6: Validate checkpoint integrity before using it
    if (!validateCheckpoint(data)) {
        cerr << "[Checkpoint] Loaded checkpoint failed validation\n";
        return false;
    }
    
    // Log success with statistics
    cout << "[Checkpoint] Rank " << rank << " loaded checkpoint from iteration " 
         << data.metadata.iteration << " (" << data.wordCounts.size() << " unique words)\n";
    
    return true;
}

/**
 * @brief Check if any checkpoint file exists for the given rank
 * 
 * Simple wrapper around getLatestCheckpoint() that returns a boolean.
 * 
 * @param rank MPI rank to check for
 * @param checkpoint_dir Directory where checkpoint files are stored
 * @return true if at least one checkpoint file exists, false otherwise
 */
bool checkpointExists(int rank, const string& checkpoint_dir) {
    return !getLatestCheckpoint(rank, checkpoint_dir).empty();
}

/**
 * @brief Find the most recent checkpoint file for a given rank
 * 
 * This function searches for checkpoint files matching the pattern
 * checkpoint_rank{X}_iter{Y}.dat and returns the one with the highest
 * iteration number. Uses a simple brute-force search from high to low
 * iteration numbers.
 * 
 * Search Strategy:
 * - Start from iteration 10000 and count down to 0
 * - Test if each potential filename exists
 * - Return first match found (highest iteration)
 * 
 * @param rank MPI rank to search for
 * @parSearch for checkpoint files by testing existence from high to low iteration
    // This is a simple approach that works across platforms without filesystem APIs
    
    for (long long iter = 10000; iter >= 0; --iter) {
        ostringstream filename;
        filename << checkpoint_dir << "/checkpoint_rank" << rank << "_iter" << iter << ".dat";
        
        // Test if file exists by attempting to open it
        ifstream test(filename.str());
        if (test.good()) {
            test.close();
            return filename.str();  // Found the latest checkpoint
        }
    }
    
    // No checkpoint found
    return "";
}

/**
 * @brief Delete the most recent checkpoint file for a rank
 * 
 * Finds and removes the latest checkpoint file. Useful for cleanup
 * after successful completion or for testing purposes.
 * 
 * @param rank MPI rank whose checkpoint should be deleted
 * @param checkpoint_dir Directory where checkpoint files are stored
 * @return true if checkpoint was found and deleted, false otherwise
 */
    }
    
    cout << "[Checkpoint] Rank " << rank << " loaded checkpoint from iteration " 
         << data.metadata.iteration << " (" << data.wordCounts.size() << " unique words)\n";
    
    return true;
}

// Check if checkpoint exists for rank
bool checkpointExists(int rank, const string& checkpoint_dir) {
    return !getLatestCheckpoint(rank, checkpoint_dir).empty();
}

// Get latest checkpoint file for rank
string getLatestCheckpoint(int rank, const string& checkpoint_dir) {
    // Look for checkpoint files matching pattern
    ostringstream pattern;
    pattern << checkpoint_dir << "/checkpoint_rank" << rank << "_iter";
    
    // Simple approach: try to find the most recent one by checking files
    // In production, you'd use directory listing
    for (long long iter = 10000; iter >= 0; --iter) {
        ostringstream filename;
        filename << checkpoint_dir << "/checkpoint_rank" << rank << "_iter" << iter << ".dat";
        
        ifstream test(filename.str());
        if (test.good()) {
            test.close();
            return filename.str();
        }
    }
    
    return "";
}

// Delete checkpoint file
bool deleteCheckpoint(int rank, const string& checkpoint_dir) {
    string filename = getLatestCheckpoint(rank, checkpoint_dir);
    if (filename.empty()) {
        return false;
    }
    
    if (remove(filename.c_str()) == 0) {
        cout << "[Checkpoint] Deleted checkpoint: " << filename << "\n";
        return true;
    }
    
    return false;
}

} // namespace Checkpoint
