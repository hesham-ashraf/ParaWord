#include <mpi.h>
#include <iostream>
#include <fstream>
#include <string>

using namespace std;

bool is_space(char c) {
    return c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f';
}

int main(int argc, char* argv[]) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    // ---------- 1. Choose input file ----------
    string filename = "sample2.txt";
    if (argc > 1) {
        filename = argv[1];
    }

    string buffer;          // full file (only on rank 0)
    long long N = 0;        // total bytes

    // ---------- 2. Rank 0 reads full file ----------
    if (rank == 0) {
        ifstream file(filename, ios::binary);
        if (!file.is_open()) {
            cerr << "Error: could not open file " << filename << "\n";
            MPI_Abort(MPI_COMM_WORLD, 1);
        }

        file.seekg(0, ios::end);
        N = file.tellg();
        file.seekg(0, ios::beg);

        buffer.resize(N);
        if (N > 0) {
            file.read(&buffer[0], N);
        }
        file.close();

        cout << "File: " << filename << ", size = " << N << " bytes\n";
    }

    // ---------- 3. Broadcast file size (collective #1) ----------
    MPI_Bcast(&N, 1, MPI_LONG_LONG, 0, MPI_COMM_WORLD);

    if (N == 0) {
        if (rank == 0) {
            cout << "Empty file. Nothing to do.\n";
        }
        MPI_Finalize();
        return 0;
    }

    // ---------- 4. Domain decomposition (1D block split) ----------
    long long base = N / size;
    long long rem  = N % size;

    // ranks [0..rem-1] get base+1 bytes, others get base
    long long local_N = base + (rank < rem ? 1 : 0);
    long long start   = rank * base + (rank < rem ? rank : rem);

    string local;
    local.resize(local_N);

    // ---------- 5. Distribute file chunks (point-to-point Send/Recv) ----------
    if (rank == 0) {
        for (int r = 0; r < size; ++r) {
            long long r_local_N = base + (r < rem ? 1 : 0);
            long long r_start   = r * base + (r < rem ? r : rem);

            if (r == 0) {
                for (long long i = 0; i < r_local_N; ++i) {
                    local[i] = buffer[r_start + i];
                }
            } else {
                MPI_Send(&buffer[r_start], (int)r_local_N, MPI_CHAR, r, 0, MPI_COMM_WORLD);
            }
        }
    } else {
        MPI_Recv(&local[0], (int)local_N, MPI_CHAR, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }

    // ---------- 6. Start timing ----------
    MPI_Barrier(MPI_COMM_WORLD);
    double t0 = MPI_Wtime();

    // ---------- 7. Non-blocking halo exchange ----------
    char left_halo  = ' ';   // char before my chunk
    char right_halo = ' ';   // char after my chunk
    MPI_Request reqs[4];
    int req_count = 0;

    // Post Irecv for halos
    if (rank > 0) {
        MPI_Irecv(&left_halo, 1, MPI_CHAR, rank - 1, 1, MPI_COMM_WORLD, &reqs[req_count++]);
    }
    if (rank < size - 1) {
        MPI_Irecv(&right_halo, 1, MPI_CHAR, rank + 1, 0, MPI_COMM_WORLD, &reqs[req_count++]);
    }

    // Post Isend for boundary chars (if I have data)
    if (local_N > 0) {
        if (rank > 0) {
            MPI_Isend(&local[0], 1, MPI_CHAR, rank - 1, 0, MPI_COMM_WORLD, &reqs[req_count++]);
        }
        if (rank < size - 1) {
            MPI_Isend(&local[local_N - 1], 1, MPI_CHAR, rank + 1, 1, MPI_COMM_WORLD, &reqs[req_count++]);
        }
    }

    // ---------- 8. Compute interior word starts (overlap comm & comp) ----------
    long long local_words = 0;

    if (local_N >= 2) {
        // interior indices 1 .. local_N-1
        for (long long i = 1; i < local_N; ++i) {
            if (!is_space(local[i]) && is_space(local[i - 1])) {
                local_words++;
            }
        }
        // note: index 0 is left for boundary fix
    }

    // ---------- 9. Wait for halos, then fix boundary at index 0 ----------
    MPI_Waitall(req_count, reqs, MPI_STATUSES_IGNORE);

    if (local_N == 1) {
        // only one character in this chunk
        if (!is_space(local[0])) {
            bool prev_is_space = (rank == 0) ? true : is_space(left_halo);
            if (prev_is_space) {
                local_words++;
            }
        }
    } else if (local_N >= 2) {
        // we didn't process i = 0 before
        if (!is_space(local[0])) {
            bool prev_is_space = (rank == 0) ? true : is_space(left_halo);
            if (prev_is_space) {
                local_words++;
            }
        }
    }

    // ---------- 10. Stop timing ----------
    MPI_Barrier(MPI_COMM_WORLD);
    double t1 = MPI_Wtime();
    double local_time = t1 - t0;

    // ---------- 11. Reduce runtime (collective #2) ----------
    double max_time = 0.0;
    MPI_Reduce(&local_time, &max_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    // ---------- 12. Reduce word counts ----------
    long long global_words = 0;
    MPI_Reduce(&local_words, &global_words, 1, MPI_LONG_LONG,
               MPI_SUM, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        cout << "Total words: " << global_words << "\n";
        cout << "Elapsed time (max over ranks): " << max_time << " seconds\n";
    }

    MPI_Finalize();
    return 0;
}
#include <omp.h>