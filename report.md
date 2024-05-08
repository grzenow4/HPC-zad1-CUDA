# Author: Grzegorz Nowakowski

## Description of the implementation
My solution is C++ code with a helper library that contains the `HashMap` class implementation.

### HashMap
The `HashMap` class contains a static vector of size set in the constructor, which contains up to half of its size entries.

An entry is a struct with `variant` and `dbEntry` inside:
- `variant` is of type `Variant`, which is a struct representing a `variant` by chromosome, position, REF and ALT values.
- `dbEntry` is of type `std::string`, which represents an entry from the database for the variant which it is paired with. Generally, `variant` is taken from `dbEntry` for convenience.

The entry is inserted into `HashMap` under the index, which is calculated as follows:
```
idx = hash(variant) % HASHMAP_SIZE
```
Hash collisions are being resolved using [linear probing](https://en.wikipedia.org/wiki/Linear_probing).

### Indexing
Indexing is performed chunk by chunk. For every set of `CHUNK_SIZE = HASHMAP_SIZE / 2` lines from the database, a corresponding `HashMap` is created and written to the index file. Basically, index file contains the same lines as the database file, but each line is prefixed with the index, under which this line is stored in the `HashMap`.

### Matching
Initially, the program creates an array of hashes for variants from the input file and sends it to the GPU. Then, for every `HashMap` from the index file that is easy to rebuild, it sends the hashes of `Variant`s from the `HashMap` to the GPU and performs the matching of the input with the single `HashMap`. As a result, it creates an array of integers, when a non-zero integer under i-th index means that there is a match of the i-th input line with the map. After matching, on the CPU side, every match is then written to the output file by extracting a line from the map.

## Quality tests
The program works correctly on the subset of the database provided and inputs with millions of lines. 

## Performance tests
Sequential version of the code runs about 4.3s. After adding CUDA and performing matching on the GPU side, the times are as follows:
- 13ms only GPU time.
- 10.3s the whole program time.
The reported times represent averages from 10 program executions, excluding the two lowest and two highest times.

Sending maps and input to the GPU is very time-consuming, but parallel matching on the GPU is significantly faster.
