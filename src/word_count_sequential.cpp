#include <iostream>
#include <fstream>
#include <unordered_map>
#include <string>
#include <chrono>

using namespace std;

int main() {
    ifstream file("data/sample.txt"); // Open the text file from the data folder
    string word;
    unordered_map<string, int> wordCount;

    // Start the timer for performance measurement
    auto start = chrono::high_resolution_clock::now();

    // Read each word and count occurrences
    while (file >> word) {
        wordCount[word]++;
    }

    // Stop the timer
    auto end = chrono::high_resolution_clock::now();
    chrono::duration<double> duration = end - start;
    cout << "Time: " << duration.count() << " seconds." << endl;

    // Output the word counts
    for (const auto& entry : wordCount) {
        cout << entry.first << ": " << entry.second << endl;
    }

    return 0;
}
