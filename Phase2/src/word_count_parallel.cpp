#include <omp.h>
#include <iostream>
#include <fstream>
#include <unordered_map>
#include <string>
#include <chrono>

using namespace std;

int main() {
    ifstream file("sample.txt");  
    string word;
    unordered_map<string, int> wordCount;

    // Start the timer for performance measurement
    auto start = chrono::high_resolution_clock::now();

    #pragma omp parallel
    {
        unordered_map<string, int> localCount;  // Thread-local word count

        // Parallelize the loop to process words
        #pragma omp for
        for (int i = 0; i < 1000000; i++) { 
            localCount[word]++;
        }

        // Merge the local count into the global wordCount
        #pragma omp critical
        {
            for (const auto& entry : localCount) {
                wordCount[entry.first] += entry.second;
            }
        }
    }

    // Stop the timer
    auto end = chrono::high_resolution_clock::now();
    chrono::duration<double> duration = end - start;
    cout << "Time: " << duration.count() << " seconds." << endl;

    // Print the word counts
    for (const auto& entry : wordCount) {
        cout << entry.first << ": " << entry.second << endl;
    }

    return 0;
}
