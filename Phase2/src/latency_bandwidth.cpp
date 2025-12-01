#include <mpi.h>
#include <iostream>
#include <vector>

using namespace std;

int main(int argc, char* argv[]) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if (size != 2) {
        if (rank == 0) {
            cerr << "This benchmark must be run with exactly 2 processes.\n";
        }
        MPI_Finalize();
        return 1;
    }

    int iters = 1000;

    if (rank == 0) {
        cout << "#msg_bytes latency_sec bandwidth_bytes_per_sec\n";
    }

    for (int msg_bytes = 8; msg_bytes <= (1 << 20); msg_bytes *= 2) { // 8 .. 1MB
        vector<char> buf(msg_bytes, 'x');

        MPI_Barrier(MPI_COMM_WORLD);
        double t0 = MPI_Wtime();

        for (int i = 0; i < iters; ++i) {
            if (rank == 0) {
                MPI_Send(buf.data(), msg_bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD);
                MPI_Recv(buf.data(), msg_bytes, MPI_CHAR, 1, 0, MPI_COMM_WORLD,
                         MPI_STATUS_IGNORE);
            } else {
                MPI_Recv(buf.data(), msg_bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD,
                         MPI_STATUS_IGNORE);
                MPI_Send(buf.data(), msg_bytes, MPI_CHAR, 0, 0, MPI_COMM_WORLD);
            }
        }

        MPI_Barrier(MPI_COMM_WORLD);
        double t1 = MPI_Wtime();
        double total = t1 - t0;
        double avg_round_trip = total / iters;
        double latency = avg_round_trip / 2.0;    // seconds (one way)
        double bandwidth = msg_bytes / latency;   // bytes per second

        if (rank == 0) {
            cout << msg_bytes << " " << latency << " " << bandwidth << "\n";
        }
    }

    MPI_Finalize();
    return 0;
}
