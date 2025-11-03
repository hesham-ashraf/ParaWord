#include <iostream>
#include <fstream>
#include <unordered_map>
#include <string>
#include <chrono>

using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    ifstream file("sample2.txt");  
    if (!file.is_open()) {
        cerr << "Error: Could not open file.\n";
        return 1;
    }

    unordered_map<string, int> wordCount;
    string word;
    size_t totalWords = 0;

    // Start timing before the loop
    auto start = chrono::high_resolution_clock::now();

    // Count words
    while (file >> word) {
        wordCount[word]++;
        totalWords++;
    }

    //  Stop timing after counting is done
    auto end = chrono::high_resolution_clock::now();
    chrono::duration<double> duration = end - start;

    // Print total time and total words to verify same workload
    cout << "Time: " << duration.count() << " seconds." << endl;
    cout << "Total words processed: " << totalWords << endl;
    //// For Debugging
    //// Print first few word counts to check correctness

    // int printed = 0;
    // for (const auto &entry : wordCount) {
    //     if (printed >= 25) break;
    //     cout << entry.first << ": " << entry.second << endl;
    //     printed++;
    // }

    return 0;
}