#include <chrono>
#include <fstream>
#include <sstream>
#include <string>

#include "cuda.h"
#include "common/errors.h"
#include "common/hashmap.hh"

#define HASH_MAP_SIZE 1048576

static size_t takeIdxFromEntry(std::string& entry) {
    std::string tmp;
    std::getline(std::stringstream(entry), tmp, '\t');
    entry.erase(0, tmp.length() + 1);
    return std::stoi(tmp);
}

static Variant takeVariantFromEntry(const std::string& entry) {
    Variant variant;

    std::stringstream ss(entry);
    std::string token;

    ss >> token;
    variant.chr = std::stoi(token);

    ss >> token;
    variant.pos = std::stoi(token);

    ss >> token;
    variant.ref = token[0];

    ss >> token;
    variant.alt = token[0];

    return variant;
}

static Variant takeVariantFromVCF(const std::string& entry) {
    Variant variant;

    std::stringstream ss(entry);
    std::string token;

    ss >> token;
    variant.chr = std::stoi(token);

    ss >> token;
    variant.pos = std::stoi(token);

    ss >> token >> token;
    variant.ref = token[0];

    ss >> token;
    variant.alt = token[0];

    return variant;
}

void indexDatabase(const std::string& dbNSFP_file, const std::string& index_file) {
    std::ifstream input_file(dbNSFP_file);
    std::ofstream output_file(index_file);

    if (!input_file.is_open() || !output_file.is_open()) {
        std::cout << "Error opening a file";
        exit(EXIT_FAILURE);
    }

    std::string line;
    std::getline(input_file, line);

    int chunk_count = 0;
    HashMap *map = new HashMap(HASH_MAP_SIZE * 2);

    while (std::getline(input_file, line)) {
        chunk_count++;

        Variant variant = takeVariantFromEntry(line);
        map->insert(variant, line);

        if (chunk_count == HASH_MAP_SIZE) {
            chunk_count = 0;
            map->writeToFile(index_file);
            delete map;
            map = new HashMap(HASH_MAP_SIZE * 2);
        }
    }

    if (chunk_count > 0) {
        map->writeToFile(index_file);
        delete map;
    }

    input_file.close();
    output_file.close();
}

void matchDatabase(const std::string& file1, const std::string& file2, const std::string& file3) {
    std::ifstream input_file(file1);
    std::ifstream index_file(file2);
    std::ofstream output_file(file3);

    if (!input_file.is_open() || !index_file.is_open() || !output_file.is_open()) {
        std::cout << "Error opening a file";
        exit(EXIT_FAILURE);
    }

    std::vector<HashMap*> vec;
    std::string line;

    while (std::getline(index_file, line)) {
        if (line == "HashMap:") {
            vec.push_back(new HashMap(HASH_MAP_SIZE * 2));
            continue;
        }

        size_t idx = takeIdxFromEntry(line);
        Variant variant = takeVariantFromEntry(line);
        vec.back()->insertAt(variant, line, idx);
    }

    std::getline(input_file, line);
    std::getline(input_file, line);
    while (std::getline(input_file, line)) {
        Variant variant = takeVariantFromVCF(line);
        for (auto map: vec) {
            std::string entry = map->find(variant);
            if (entry != "") {
                output_file << entry << std::endl;
                break;
            }
        }
    }

    input_file.close();
    index_file.close();
    output_file.close();
}

__global__ void kernel() {

}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        std::cout << "Usage: " << argv[0] << " path/to/variant.vcf path/to/your/output/index path/to/matched/output.tsv\n";
        std::cout << "Index the database: " << argv[0] << " -i path/to/dbNSFP.tsv path/to/your/output/index\n";
        return 1;
    }

    std::string flag = argv[1];
    if (flag == "-i") {
        indexDatabase(argv[2], argv[3]);
        return 0;
    }

    matchDatabase(argv[1], argv[2], argv[3]);

    return 0;
}
