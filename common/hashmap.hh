#pragma once

#include <iostream>
#include <string>
#include <vector>

const uint64_t INT_MAX_LEN = 10;

typedef struct {
    uint64_t chr;
    uint64_t pos;
    char ref;
    char alt;
} Variant;

typedef struct {
    Variant variant;
    std::string dbEntry;
} HashEntry;

bool operator==(const Variant& v1, const Variant& v2) {
    return v1.chr == v2.chr && v1.pos == v2.pos && v1.ref == v2.ref && v1.alt == v2.alt;
}

uint64_t alleleToInt(char allele) {
    switch (allele) {
        case 'A': return 0;
        case 'C': return 1;
        case 'G': return 2;
        case 'T': return 3;
        default:
            std::cout << "Error parsing " << allele << " to uint64";
            exit(EXIT_FAILURE);
    }
}

uint64_t hashVariant(const Variant& variant) {
    return variant.chr * pow(10, INT_MAX_LEN + 2) +
           variant.pos * 100 +
           alleleToInt(variant.ref) * 10 +
           alleleToInt(variant.alt);
}

class HashMap {
private:
    std::vector<HashEntry> entries;
    size_t capacity;
    size_t size;

public:
    HashMap(int init_capacity) : capacity(init_capacity), size(0) {
        entries.resize(capacity);
    }

    ~HashMap() {
        for (size_t i = 0; i < capacity; i++) {
            if (!entries[i].dbEntry.empty()) {
                entries[i].dbEntry.clear();
            }
        }
    }

    void insertAt(Variant variant, std::string dbEntry, size_t idx) {
        if (dbEntry.empty()) {
            std::cout << "Error inserting an empty string to the HashMap";
            exit(EXIT_FAILURE);
        }

        if (size >= capacity / 2) {
            std::cout << "Error inserting more than `capacity / 2` elements to the HashMap";
            exit(EXIT_FAILURE);
        }

        size++;
        entries[idx] = {variant = variant, dbEntry = dbEntry};
    }

    void insert(Variant variant, std::string dbEntry) {
        uint64_t hash = hashVariant(variant);
        size_t index = static_cast<size_t>(hash & capacity - 1);

        while (!entries[index].dbEntry.empty()) {
            index++;
            if (index == capacity) {
                index = 0;
            }
        }

        insertAt(variant, dbEntry, index);
    }

    std::string getEntryAt(uint64_t idx) {
        if (idx >= capacity) {
            std::cout << "Error index " << idx << " out of range";
            exit(EXIT_FAILURE);
        }
        return entries[idx].dbEntry;
    }

    std::string find(Variant variant) {
        uint64_t hash = hashVariant(variant);
        size_t index = static_cast<size_t>(hash & (capacity - 1));

        while (!entries[index].dbEntry.empty()) {
            if (variant == entries[index].variant) {
                return entries[index].dbEntry;
            }
            index++;
            if (index == capacity) {
                index = 0;
            }
        }

        return "";
    }

    void writeToFile(const std::string& file) {
        std::ofstream output_file(file, std::ios_base::app);
        if (!output_file.is_open()) {
            std::cout << "Error opening a file";
            exit(EXIT_FAILURE);
        }

        output_file << "HashMap:\n";
        for (size_t i = 0; i < capacity; i++) {
            if (!entries[i].dbEntry.empty()) {
                Variant variant = entries[i].variant;
                std::string dbEntry = entries[i].dbEntry;
                std::string combinedData =
                        std::to_string(i) + "\t" +
                        dbEntry;
                output_file << combinedData << std::endl;
            }
        }

        output_file.close();
    }

    uint64_t *dumpVariants() {
        uint64_t *res = (uint64_t*) malloc(capacity * sizeof(uint64_t));
        for (size_t i = 0; i < capacity; i++) {
            if (!entries[i].dbEntry.empty()) {
                res[i] = hashVariant(entries[i].variant);
            }
        }
        return res;
    }

    void printMap() {
        std::cout << "size = " << size << " , capacity = " << capacity << "\n";
        for (size_t i = 0; i < capacity; i++) {
            if (!entries[i].dbEntry.empty()) {
                std::cout << "(" << hashVariant(entries[i].variant) << " -> " << i << ") " << entries[i].dbEntry << "\n";
            }
        }
    }
};
