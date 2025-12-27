/**
 * @file word_count_resilient.cpp
 * @brief Fault-tolerant distributed word counter with MPI, checkpointing, and failure recovery
 * 
 * This program implements a resilient master-worker word counting system using MPI.
 * Key features:
 * - Checkpointing: Periodic state saves for recovery
 * - Heartbeat mechanism: Detects worker failures
 * - Work redistribution: Reassigns failed worker's tasks
 * - Automatic recovery: Resumes from last checkpoint after failure
 * 
 * Architecture:
 * - Rank 0 (Master): Assigns work, monitors workers, handles failures
 * - Rank 1+ (Workers): Process text chunks, send heartbeats, create checkpoints
 * 
 * Failure Recovery Process:
 * 1. Master detects worker failure via heartbeat timeout
 * 2. Master reassigns failed worker's tasks to surviving workers
 * 3. On restart, worker loads last checkpoint and resumes
 * 
 * @author Phase 3 Implementation
 * @date December 2025
 */

#include <mpi.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
#include <ctime>
#include <cstring>
#include <chrono>
#include <algorithm>
#include "checkpoint.h"

using namespace std;

//==============================================================================
// CONFIGURATION CONSTANTS
//==============================================================================

const int CHECKPOINT_INTERVAL = 1000;   ///< Save checkpoint every N iterations
const double HEARTBEAT_INTERVAL = 2.0;  ///< Worker sends heartbeat every 2 seconds
const double HEARTBEAT_TIMEOUT = 5.0;   ///< Master considers worker failed after 5 seconds
const int MASTER_RANK = 0;              ///< MPI rank 0 is always the master

//==============================================================================
// MPI MESSAGE TAGS
//==============================================================================

/**
 * @enum MessageTag
 * @brief Tags for different types of MPI messages
 */
enum MessageTag {
    TAG_WORK_ASSIGNMENT = 1,   ///< Master → Worker: Assigns work chunk
    TAG_WORK_RESULT = 2,       ///< Worker → Master: Returns results
    TAG_HEARTBEAT = 3,         ///< Worker → Master: Periodic alive signal
    TAG_FAILURE_DETECTED = 4,  ///< Master → Worker: Notifies of failure
    TAG_SHUTDOWN = 5,          ///< Master → Worker: Shutdown signal
    TAG_CHECKPOINT_SYNC = 6    ///< Master ↔ Worker: Checkpoint synchronization
};

//==============================================================================
// DATA STRUCTURES
//==============================================================================

/**
 * @enum WorkStatus
 * @brief Tracks the lifecycle state of a work unit
 */
enum WorkStatus {
    WORK_PENDING,    ///< Work created but not yet assigned
    WORK_ASSIGNED,   ///< Work assigned to a worker
    WORK_COMPLETED,  ///< Work finished successfully
    WORK_FAILED      ///< Work failed due to worker failure
};

/**
 * @struct WorkUnit
 * @brief Represents a chunk of work assigned to a worker
 * 
 * The master maintains a vector of WorkUnits to track all work
 * assignments and handle failure recovery.
 */
struct WorkUnit {
    int worker_rank;                              ///< Which worker this is assigned to
    long long start_pos;                          ///< Byte offset in file to start
    long long chunk_size;                         ///< Number of bytes to process
    WorkStatus status;                            ///< Current status of this work
    time_t assigned_time;                         ///< When work was assigned
    unordered_map<string, int> results;           ///< Word counts (filled when complete)
};

/**
 * @struct ProcessState
 * @brief Master's tracking information for each worker process
 * 
 * Used by the master to implement failure detection through
 * heartbeat monitoring.
 */
struct ProcessState {
    bool is_alive;           ///< Is process currently responsive?
    time_t last_heartbeat;   ///< Timestamp of last heartbeat received
    int assigned_work_id;    ///< ID of work currently assigned (-1 if idle)
};

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

/**
 * @brief Check if a character is whitespace
 * @param c Character to test
 * @return true if c is space, newline, tab, carriage return, or form feed
 */
bool is_space(char c) {
    return c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f';
}

/**
 * @brief Thread-safe logging with timestamps and rank information
 * 
 * Outputs messages in format: [timestamp] [Rank X] message
 * Uses platform-specific time formatting (ctime_s on Windows, ctime on Unix)
 * 
 * @param rank MPI rank of the process logging the message
 * @param message Text message to log
 */
void log_message(int rank, const string& message) {
    time_t now = time(nullptr);
    char timestamp[26];
    #ifdef _WIN32
        ctime_s(timestamp, sizeof(timestamp), &now);  // Windows thread-safe version
    #else
        strcpy(timestamp, ctime(&now));                // Unix version
    #endif
    timestamp[24] = '\0'; // Remove newline character
    cout << "[" << timestamp << "] [Rank " << rank << "] " << message << endl;
}

/**
 * @brief Count words in a text chunk with proper boundary handling
 * 
 * This function handles word boundaries correctly when processing chunks
 * of a larger text. The left_boundary parameter is used to determine if
 * the first character starts a new word or continues from the previous chunk.
 * 
 * Algorithm:
 * - Words are delimited by whitespace (space, tab, newline, etc.)
 * - Handles edge case where chunk starts mid-word using left_boundary
 * - Returns frequency count for each unique word
 * 
 * @param text Text chunk to process
 * @param left_boundary Character immediately before this chunk (for boundary detection)
 * @return Map of words to their frequency counts
 * 
 * @note Essential for correct distributed word counting across file chunks
 */
unordered_map<string, int> count_words(const string& text, char left_boundary = ' ') {
    unordered_map<string, int> wordCounts;
    string word;
    bool in_word = false;
    
    for (size_t i = 0; i < text.length(); ++i) {
        char c = text[i];
        
        if (!is_space(c)) {
            // Check if this is the start of a new word
            if (!in_word) {
                char prev = (i == 0) ? left_boundary : text[i - 1];
                if (is_space(prev)) {
                    word.clear();
                    in_word = true;
                }
            }
            if (in_word) {
                word += c;
            }
        } else {
            if (in_word) {
                if (!word.empty()) {
                    wordCounts[word]++;
                }
                word.clear();
                in_word = false;
            }
        }
    }
    
    // Handle word at end of text
    if (in_word && !word.empty()) {
        wordCounts[word]++;
    }
    
    return wordCounts;
}

// Worker process function
void worker_process(int rank, int size) {
    log_message(rank, "Worker started");
    
    // Set up error handler for resilience
    MPI_Comm_set_errhandler(MPI_COMM_WORLD, MPI_ERRORS_RETURN);
    
    // Check for existing checkpoint
    CheckpointData checkpoint;
    bool has_checkpoint = Checkpoint::loadCheckpoint(rank, checkpoint);
    
    long long iteration = has_checkpoint ? checkpoint.metadata.iteration : 0;
    unordered_map<string, int> wordCounts = has_checkpoint ? checkpoint.wordCounts : unordered_map<string, int>();
    
    if (has_checkpoint) {
        log_message(rank, "Resuming from checkpoint at iteration " + to_string(iteration));
    }
    
    auto last_heartbeat = chrono::steady_clock::now();
    auto last_checkpoint = chrono::steady_clock::now();
    
    while (true) {
        // Send heartbeat to master periodically
        auto now = chrono::steady_clock::now();
        double elapsed = chrono::duration<double>(now - last_heartbeat).count();
        
        if (elapsed >= HEARTBEAT_INTERVAL) {
            int heartbeat_msg = rank;
            int result = MPI_Send(&heartbeat_msg, 1, MPI_INT, MASTER_RANK, TAG_HEARTBEAT, MPI_COMM_WORLD);
            if (result != MPI_SUCCESS) {
                log_message(rank, "ERROR: Failed to send heartbeat");
            }
            last_heartbeat = now;
        }
        
        // Check for work assignment from master
        MPI_Status status;
        int flag;
        MPI_Iprobe(MASTER_RANK, MPI_ANY_TAG, MPI_COMM_WORLD, &flag, &status);
        
        if (flag) {
            if (status.MPI_TAG == TAG_WORK_ASSIGNMENT) {
                // Receive work assignment
                long long work_data[3]; // [start_pos, chunk_size, work_id]
                MPI_Recv(work_data, 3, MPI_LONG_LONG, MASTER_RANK, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                long long start_pos = work_data[0];
                long long chunk_size = work_data[1];
                long long work_id = work_data[2];
                
                if (chunk_size == 0) {
                    // No more work - shutdown signal
                    log_message(rank, "Received shutdown signal");
                    break;
                }
                
                log_message(rank, "Received work: position " + to_string(start_pos) + ", size " + to_string(chunk_size));
                
                // Receive the actual text chunk
                string chunk(chunk_size, '\0');
                MPI_Recv(&chunk[0], chunk_size, MPI_CHAR, MASTER_RANK, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                // Receive boundary character
                char boundary;
                MPI_Recv(&boundary, 1, MPI_CHAR, MASTER_RANK, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                // Process the chunk
                log_message(rank, "Processing chunk...");
                auto local_counts = count_words(chunk, boundary);
                
                // Merge results
                for (const auto& pair : local_counts) {
                    wordCounts[pair.first] += pair.second;
                }
                
                iteration++;
                
                // Checkpoint periodically
                now = chrono::steady_clock::now();
                double checkpoint_elapsed = chrono::duration<double>(now - last_checkpoint).count();
                
                if (iteration % CHECKPOINT_INTERVAL == 0 || checkpoint_elapsed >= 10.0) {
                    CheckpointData cp;
                    cp.metadata.rank = rank;
                    cp.metadata.iteration = iteration;
                    cp.metadata.total_words = 0;
                    for (const auto& p : wordCounts) cp.metadata.total_words += p.second;
                    cp.metadata.timestamp = time(nullptr);
                    cp.metadata.version = 1;
                    cp.metadata.checksum = Checkpoint::calculateChecksum(wordCounts);
                    cp.wordCounts = wordCounts;
                    cp.processed_bytes = chunk_size;
                    cp.start_position = start_pos;
                    cp.chunk_size = chunk_size;
                    
                    Checkpoint::saveCheckpoint(cp);
                    last_checkpoint = now;
                }
                
                // Send results back to master
                int result_size = local_counts.size();
                MPI_Send(&result_size, 1, MPI_INT, MASTER_RANK, TAG_WORK_RESULT, MPI_COMM_WORLD);
                
                for (const auto& pair : local_counts) {
                    int word_len = pair.first.length();
                    MPI_Send(&word_len, 1, MPI_INT, MASTER_RANK, TAG_WORK_RESULT, MPI_COMM_WORLD);
                    MPI_Send(pair.first.c_str(), word_len, MPI_CHAR, MASTER_RANK, TAG_WORK_RESULT, MPI_COMM_WORLD);
                    MPI_Send(&pair.second, 1, MPI_INT, MASTER_RANK, TAG_WORK_RESULT, MPI_COMM_WORLD);
                }
                
                log_message(rank, "Work completed, sent " + to_string(result_size) + " unique words");
            }
            else if (status.MPI_TAG == TAG_SHUTDOWN) {
                log_message(rank, "Received shutdown command");
                break;
            }
        }
    }
    
    log_message(rank, "Worker shutting down");
}

// Master process function
void master_process(int rank, int size, const string& filename) {
    log_message(rank, "Master started with " + to_string(size) + " processes");
    
    // Set up error handler
    MPI_Comm_set_errhandler(MPI_COMM_WORLD, MPI_ERRORS_RETURN);
    
    // Read input file
    ifstream file(filename, ios::binary);
    if (!file.is_open()) {
        cerr << "Error: could not open file " << filename << "\n";
        MPI_Abort(MPI_COMM_WORLD, 1);
    }
    
    file.seekg(0, ios::end);
    long long file_size = file.tellg();
    file.seekg(0, ios::beg);
    
    string buffer(file_size, '\0');
    file.read(&buffer[0], file_size);
    file.close();
    
    log_message(rank, "Read file: " + filename + " (" + to_string(file_size) + " bytes)");
    
    // Initialize work units and process state
    int num_workers = size - 1;
    long long chunk_size = file_size / (num_workers * 4); // Create more chunks for better load balancing
    if (chunk_size < 1000) chunk_size = 1000;
    
    vector<WorkUnit> work_units;
    vector<ProcessState> process_states(size);
    
    // Initialize process states
    for (int i = 0; i < size; ++i) {
        process_states[i].is_alive = true;
        process_states[i].last_heartbeat = time(nullptr);
        process_states[i].assigned_work_id = -1;
    }
    
    // Create work units
    int work_id = 0;
    for (long long pos = 0; pos < file_size; pos += chunk_size) {
        WorkUnit unit;
        unit.start_pos = pos;
        unit.chunk_size = min(chunk_size, file_size - pos);
        unit.status = WORK_PENDING;
        unit.worker_rank = -1;
        work_units.push_back(unit);
        work_id++;
    }
    
    log_message(rank, "Created " + to_string(work_units.size()) + " work units");
    
    // Track results
    unordered_map<string, int> global_word_counts;
    int completed_work = 0;
    int next_work_to_assign = 0;
    
    auto start_time = chrono::steady_clock::now();
    
    // Main master loop
    while (completed_work < work_units.size()) {
        // Check for heartbeats and detect failures
        MPI_Status status;
        int flag;
        MPI_Iprobe(MPI_ANY_SOURCE, TAG_HEARTBEAT, MPI_COMM_WORLD, &flag, &status);
        
        if (flag) {
            int heartbeat_msg;
            int source = status.MPI_SOURCE;
            MPI_Recv(&heartbeat_msg, 1, MPI_INT, source, TAG_HEARTBEAT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            process_states[source].last_heartbeat = time(nullptr);
            process_states[source].is_alive = true;
        }
        
        // Detect timeouts (failures)
        time_t now = time(nullptr);
        for (int i = 1; i < size; ++i) {
            if (process_states[i].is_alive) {
                double elapsed = difftime(now, process_states[i].last_heartbeat);
                if (elapsed > HEARTBEAT_TIMEOUT) {
                    log_message(rank, "FAILURE DETECTED: Rank " + to_string(i) + " timed out (no heartbeat for " + to_string(elapsed) + "s)");
                    process_states[i].is_alive = false;
                    
                    // Mark assigned work as failed
                    int work_id = process_states[i].assigned_work_id;
                    if (work_id >= 0 && work_id < work_units.size()) {
                        if (work_units[work_id].status == WORK_ASSIGNED) {
                            log_message(rank, "Reassigning work unit " + to_string(work_id) + " from failed rank " + to_string(i));
                            work_units[work_id].status = WORK_PENDING;
                            work_units[work_id].worker_rank = -1;
                        }
                    }
                    process_states[i].assigned_work_id = -1;
                }
            }
        }
        
        // Check for work results
        MPI_Iprobe(MPI_ANY_SOURCE, TAG_WORK_RESULT, MPI_COMM_WORLD, &flag, &status);
        
        if (flag) {
            int source = status.MPI_SOURCE;
            int result_size;
            MPI_Recv(&result_size, 1, MPI_INT, source, TAG_WORK_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            
            // Receive word-count pairs
            for (int i = 0; i < result_size; ++i) {
                int word_len;
                MPI_Recv(&word_len, 1, MPI_INT, source, TAG_WORK_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                string word(word_len, '\0');
                MPI_Recv(&word[0], word_len, MPI_CHAR, source, TAG_WORK_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                int count;
                MPI_Recv(&count, 1, MPI_INT, source, TAG_WORK_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                global_word_counts[word] += count;
            }
            
            // Mark work as completed
            int work_id = process_states[source].assigned_work_id;
            if (work_id >= 0 && work_id < work_units.size()) {
                work_units[work_id].status = WORK_COMPLETED;
                completed_work++;
                log_message(rank, "Work unit " + to_string(work_id) + " completed by rank " + to_string(source) + 
                           " (" + to_string(completed_work) + "/" + to_string(work_units.size()) + ")");
            }
            
            process_states[source].assigned_work_id = -1;
        }
        
        // Assign work to idle workers
        for (int worker = 1; worker < size; ++worker) {
            if (process_states[worker].is_alive && process_states[worker].assigned_work_id == -1) {
                // Find next pending work
                while (next_work_to_assign < work_units.size() && work_units[next_work_to_assign].status != WORK_PENDING) {
                    next_work_to_assign++;
                }
                
                if (next_work_to_assign < work_units.size()) {
                    WorkUnit& unit = work_units[next_work_to_assign];
                    
                    // Send work assignment
                    long long work_data[3] = {unit.start_pos, unit.chunk_size, next_work_to_assign};
                    int result = MPI_Send(work_data, 3, MPI_LONG_LONG, worker, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD);
                    
                    if (result == MPI_SUCCESS) {
                        // Send chunk data
                        MPI_Send(&buffer[unit.start_pos], unit.chunk_size, MPI_CHAR, worker, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD);
                        
                        // Send boundary character
                        char boundary = (unit.start_pos > 0) ? buffer[unit.start_pos - 1] : ' ';
                        MPI_Send(&boundary, 1, MPI_CHAR, worker, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD);
                        
                        unit.status = WORK_ASSIGNED;
                        unit.worker_rank = worker;
                        unit.assigned_time = time(nullptr);
                        process_states[worker].assigned_work_id = next_work_to_assign;
                        
                        log_message(rank, "Assigned work unit " + to_string(next_work_to_assign) + " to rank " + to_string(worker));
                        next_work_to_assign++;
                    } else {
                        log_message(rank, "ERROR: Failed to send work to rank " + to_string(worker));
                        process_states[worker].is_alive = false;
                    }
                }
            }
        }
    }
    
    auto end_time = chrono::steady_clock::now();
    double total_time = chrono::duration<double>(end_time - start_time).count();
    
    // Send shutdown signal to all workers
    for (int worker = 1; worker < size; ++worker) {
        long long work_data[3] = {0, 0, -1};
        MPI_Send(work_data, 3, MPI_LONG_LONG, worker, TAG_WORK_ASSIGNMENT, MPI_COMM_WORLD);
    }
    
    // Output results
    long long total_words = 0;
    for (const auto& pair : global_word_counts) {
        total_words += pair.second;
    }
    
    cout << "\n========== RESULTS ==========\n";
    cout << "Total unique words: " << global_word_counts.size() << "\n";
    cout << "Total word count: " << total_words << "\n";
    cout << "Execution time: " << total_time << " seconds\n";
    cout << "File size: " << file_size << " bytes\n";
    cout << "Work units: " << work_units.size() << "\n";
    cout << "Workers used: " << num_workers << "\n";
    cout << "============================\n";
    
    // Save results to file
    ofstream out("results.txt");
    out << "Unique words: " << global_word_counts.size() << "\n";
    out << "Total words: " << total_words << "\n";
    out << "Time: " << total_time << "s\n";
    out.close();
    
    log_message(rank, "Master completed successfully");
}

int main(int argc, char* argv[]) {
    MPI_Init(&argc, &argv);
    
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    if (size < 2) {
        if (rank == 0) {
            cerr << "Error: Need at least 2 processes (1 master + 1 worker)\n";
            cerr << "Usage: mpiexec -n <num_processes> word_count_resilient.exe [filename]\n";
        }
        MPI_Finalize();
        return 1;
    }
    
    string filename = "sample2.txt";
    if (argc > 1) {
        filename = argv[1];
    }
    
    try {
        if (rank == MASTER_RANK) {
            master_process(rank, size, filename);
        } else {
            worker_process(rank, size);
        }
    } catch (const exception& e) {
        log_message(rank, string("EXCEPTION: ") + e.what());
        MPI_Abort(MPI_COMM_WORLD, 1);
    }
    
    MPI_Finalize();
    return 0;
}
