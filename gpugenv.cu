#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cuda.h"
#include "common/errors.h"
#include "common/hashmap.h"

void indexDatabase(char *dbNSFP_file, char *index_file) {
    FILE *input_file = fopen(dbNSFP_file, "r");
    FILE *output_file = fopen(index_file, "wb");

    if (!input_file || !output_file) {
        printf("Error opening a file");
        exit(EXIT_FAILURE);
    }

    HashMap *map = createHashMap();

    char *line = NULL;
    size_t len = 0;
    Variant variant;

    // Discard the header line
    getline(&line, &len, input_file);

    while (getline(&line, &len, input_file) != -1) {
        char *line_copy = strdup(line);
        if (line_copy == NULL) {
            printf("Memory allocation failed");
            exit(EXIT_FAILURE);
        }

        char *token = strtok(line, "\t");
        variant.chr = atoi(token);

        token = strtok(NULL, "\t");
        variant.pos = atoi(token);

        token = strtok(NULL, "\t");
        variant.ref = token[0];

        token = strtok(NULL, "\t");
        variant.alt = token[0];

        insertHashMap(map, variant, line_copy);
    }

    printMap(map);
    fwrite(map->entries, sizeof(HashEntry), map->size, output_file);

    free(line);
    destroyHashMap(map);
    fclose(input_file);
    fclose(output_file);
}

__global__ void kernel() {

}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s path/to/variant.vcf path/to/your/output/index path/to/matched/output.tsv\n", argv[0]);
        printf("Index the database: %s -i path/to/dbNSFP.tsv path/to/your/output/index\n", argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "-i") == 0) {
        indexDatabase(argv[2], argv[3]);
        return 0;
    }

    FILE *input_file = fopen(argv[1], "r");
    FILE *index_file = fopen(argv[2], "r");
    FILE *output_file = fopen(argv[3], "wb");

    if (!input_file || !index_file || !output_file) {
        printf("Error opening a file");
        exit(EXIT_FAILURE);
    }

    fclose(input_file);
    fclose(index_file);
    fclose(output_file);

    return 0;
}
