#include <cassert>
#include <chrono>
#include <fstream>
#include <sstream>
#include <string>

#include "cuda.h"
#include "common/errors.h"
#include "common/hashmap.hh"

const int DIM = 1024;
const int N = 128;
const int M = DIM / N;

const size_t CHUNK_SIZE = 1048576;
const size_t HASHMAP_SIZE = 2 * CHUNK_SIZE;

/*
 * Index file contains `HashMap` info as follows:
 * <index>\t<whole_db_entry>
 * This function returns an index of the `whole_db_entry` in the `HashMap`
 * and removes it from the input string.
 */
static size_t takeIdxFromEntry(std::string& entry) {
    std::string tmp;
    std::getline(std::stringstream(entry), tmp, '\t');
    entry.erase(0, tmp.length() + 1);
    return std::stoi(tmp);
}

/*
 * Returns a `Variant` of the database entry.
 */
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

/*
 * Returns a `Variant` of the VCF entry.
 */
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

/*
 * Indexes the database as follows:
 * 1. Reads up to `CHUNK_SIZE` lines from the database and create a HashMap based on them.
 * 2. Writes just created map to the index file prefixed with `HashMap:` header.
 * 3. In the result, index file contains (lines_in_db / CHUNK_SIZE) `HashMap`s.
 */
void indexDatabase(const std::string& dbNSFP_file, const std::string& index_file) {
    std::ifstream input_file(dbNSFP_file);
    std::ofstream output_file(index_file);

    if (!input_file.is_open() || !output_file.is_open()) {
        std::cout << "Error opening a file";
        exit(EXIT_FAILURE);
    }

    std::string line;
    std::getline(input_file, line); // skip the header line

    int chunk_count = 0;
    HashMap *map = new HashMap(HASHMAP_SIZE);

    while (std::getline(input_file, line)) {
        chunk_count++;

        Variant variant = takeVariantFromEntry(line);
        map->insert(variant, line);

        if (chunk_count == CHUNK_SIZE) {
            chunk_count = 0;
            map->writeToFile(index_file);
            delete map;
            map = new HashMap(HASHMAP_SIZE);
        }
    }

    if (chunk_count > 0) {
        map->writeToFile(index_file);
        delete map;
    }

    input_file.close();
    output_file.close();
}

/*
 * Counts lines in the input VCF file.
 */
int countInputSize(const std::string& input) {
    std::ifstream input_file(input);

    if (!input_file.is_open()) {
        std::cout << "Error opening a file";
        exit(EXIT_FAILURE);
    }

    int line_count = 0;
    std::string line;

    while (std::getline(input_file, line)) {
        line_count++;
    }

    input_file.close();
    return line_count - 2; // subtract two header lines
}

/*
 * Reads the input file and builds the array of hashes of variants of entries
 * of the input lines. This array is then copied to GPU.
 */
void sendInputToDevice(const std::string& input, uint64_t *devInput, int size) {
    std::ifstream input_file(input);

    if (!input_file.is_open()) {
        std::cout << "Error opening a file";
        exit(EXIT_FAILURE);
    }

    uint64_t *hashes = new uint64_t[size];
    std::string line;
    std::getline(input_file, line); // skip the header line
    std::getline(input_file, line); // skip the second header line
    for (int i = 0; std::getline(input_file, line); i++) {
        assert(i < size);
        hashes[i] = hashVariant(takeVariantFromVCF(line));
    }

    HANDLE_ERROR(cudaMemcpy(devInput, hashes, size * sizeof(uint64_t), cudaMemcpyHostToDevice));

    delete[] hashes;
    input_file.close();
}

/*
 * `kernel` function takes the whole `input` and a single `map`.
 * There are N threads and M blocks. Each thread matches his part of input to
 * the map and writes every match to the `out`. `out[i] = HASHMAP_SIZE` means
 * there is no match of i-th line of the `input` in the `map`.
 */
__global__ void kernel(uint64_t *out, uint64_t *input, int input_size, uint64_t *map) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    int offset = blockDim.x * gridDim.x;

    for (int i = idx; i < input_size; i += offset) {
        out[i] = HASHMAP_SIZE;

        uint64_t hash = input[i];
        size_t index = static_cast<size_t>(hash & (HASHMAP_SIZE - 1));

        while (map[index] != 0) {
            if (hash == map[index]) {
                out[i] = index;
                break;
            }
            index++;
            if (index == HASHMAP_SIZE) {
                index = 0;
            }
        }
    }
}

/*
 * Invokes the kernel function. All `invokeKernel` calls sum the GPU execution
 * times to the `elapsedTime` variable.
 */
void invokeKernel(uint64_t *devOut, uint64_t *devInput, int input_size, uint64_t *devMap, float &elapsedTime) {
    cudaEvent_t start, stop;
    HANDLE_ERROR(cudaEventCreate(&start));
    HANDLE_ERROR(cudaEventCreate(&stop));

    HANDLE_ERROR(cudaEventRecord(start, 0));
    kernel<<<M, N>>>(devOut, devInput, input_size, devMap);
    HANDLE_ERROR(cudaEventRecord(stop, 0));
    HANDLE_ERROR(cudaEventSynchronize(stop));

    float time;
    HANDLE_ERROR(cudaEventElapsedTime(&time, start, stop));
    elapsedTime += time;

    HANDLE_ERROR(cudaEventDestroy(start));
    HANDLE_ERROR(cudaEventDestroy(stop));
}

/*
 * For each `HashMap` read from the index file, calls the kernel function, where
 * the matching takes place. Then, writes every match found in this iteration
 * to the output file.
 * Counts the time spent on GPU.
 */
void matchDatabase(const std::string& input,
                   const std::string& index,
                   const std::string& output) {
    std::ifstream index_file(index);
    std::ofstream output_file(output);

    if (!index_file.is_open() || !output_file.is_open()) {
        std::cout << "Error opening a file";
        exit(EXIT_FAILURE);
    }

    int input_size = countInputSize(input);
    float elapsedTime = 0;

    uint64_t *out = (uint64_t*) malloc(input_size * sizeof(uint64_t));
    uint64_t *devInput;
    uint64_t *devOut;
    uint64_t *devMap;

    HANDLE_ERROR(cudaMalloc((void**)&devInput, input_size * sizeof(uint64_t)));
    HANDLE_ERROR(cudaMalloc((void**)&devOut, input_size * sizeof(uint64_t)));
    HANDLE_ERROR(cudaMalloc((void**)&devMap, HASHMAP_SIZE * sizeof(uint64_t)));

    sendInputToDevice(input, devInput, input_size);

    HashMap *map = nullptr;
    std::string line;

    while (std::getline(index_file, line)) {
        if (line == "HashMap:") {
            if (map != nullptr) {
                uint64_t *tmp = map->dumpVariants();
                HANDLE_ERROR(cudaMemcpy(devMap, tmp, HASHMAP_SIZE * sizeof(uint64_t), cudaMemcpyHostToDevice));

                invokeKernel(devOut, devInput, input_size, devMap, elapsedTime);

                HANDLE_ERROR(cudaMemcpy(out, devOut, input_size * sizeof(uint64_t), cudaMemcpyDeviceToHost));
                for (int i = 0; i < input_size; i++) {
                    if (out[i] < HASHMAP_SIZE) {
                        output_file << map->getEntryAt(out[i]) << "\n";
                    }
                }

                free(tmp);
                free(map);
            }
            map = new HashMap(HASHMAP_SIZE);
        } else {
            size_t idx = takeIdxFromEntry(line);
            Variant variant = takeVariantFromEntry(line);
            map->insertAt(variant, line, idx);
        }
    }
    uint64_t *tmp = map->dumpVariants();
    HANDLE_ERROR(cudaMemcpy(devMap, tmp, HASHMAP_SIZE * sizeof(uint64_t), cudaMemcpyHostToDevice));

    invokeKernel(devOut, devInput, input_size, devMap, elapsedTime);

    HANDLE_ERROR(cudaMemcpy(out, devOut, input_size * sizeof(uint64_t), cudaMemcpyDeviceToHost));
    for (int i = 0; i < input_size; i++) {
        if (out[i] < HASHMAP_SIZE) {
            output_file << map->getEntryAt(out[i]) << "\n";
        }
    }

    free(tmp);
    free(map);
    free(out);

    std::cout << "Total GPU execution time: " << elapsedTime << " ms\n";

    HANDLE_ERROR(cudaFree(devInput));
    HANDLE_ERROR(cudaFree(devOut));
    HANDLE_ERROR(cudaFree(devMap));

    index_file.close();
    output_file.close();
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
