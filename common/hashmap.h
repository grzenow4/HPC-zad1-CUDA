#pragma once

#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define INITIAL_CAPACITY 1048576
#define INT_MAX_LEN 10

typedef struct {
    int chr;
    int pos;
    char ref;
    char alt;
} Variant;

typedef struct {
    Variant variant;
    const char *dbEntry;
} HashEntry;

typedef struct {
    HashEntry *entries;
    size_t capacity;
    size_t size;
} HashMap;

int alleleToInt(char allele) {
    switch (allele) {
        case 'A': return 0;
        case 'C': return 1;
        case 'G': return 2;
        case 'T': return 3;
        default:
            printf("Error parsing %c to int", allele);
            exit(EXIT_FAILURE);
    }
}

bool compareVariant(Variant v1, Variant v2) {
    return v1.chr == v2.chr && v1.pos == v2.pos && v1.ref == v2.ref && v1.alt == v2.alt;
}

uint64_t hashVariant(Variant variant) {
    return  variant.chr * pow(10, INT_MAX_LEN + 2) +
            variant.pos * 100 +
            alleleToInt(variant.ref) * 10 +
            alleleToInt(variant.alt);
}

HashMap *createHashMap() {
    HashMap *map = (HashMap*) malloc(sizeof(HashMap));
    if (map == NULL) {
        printf("Memory allocation failed");
        exit(EXIT_FAILURE);
    }
    map->capacity = INITIAL_CAPACITY;
    map->size = 0;
    map->entries = (HashEntry*) malloc(map->capacity * sizeof(HashEntry));
    if (map->entries == NULL) {
        free(map);
        printf("Memory allocation failed");
        exit(EXIT_FAILURE);
    }
    return map;
}

void destroyHashMap(HashMap *map) {
    for (size_t i = 0; i < map->capacity; i++) {
        free((void*) map->entries[i].dbEntry);
    }
    free(map->entries);
    free(map);
}

void insertEntry(HashEntry *entries, size_t capacity, Variant variant, const char *dbEntry, size_t *size) {
    uint64_t hash = hashVariant(variant);
    size_t index = (size_t)(hash & (uint64_t)(capacity - 1));

    while (entries[index].dbEntry != NULL) {
        index++;
        if (index == capacity) {
            index = 0;
        }
    }

    if (size != NULL) {
        dbEntry = strdup(dbEntry);
        if (dbEntry == NULL) {
            printf("Memory allocation failed");
            exit(EXIT_FAILURE);
        }
        (*size)++;
    }
    entries[index].variant = variant;
    entries[index].dbEntry = dbEntry;
}

void extendHashMap(HashMap *map) {
    size_t new_capacity = map->capacity * 2;
    if (new_capacity < map->capacity) {
        printf("Error ran out of memory");
        exit(EXIT_FAILURE);
    }
    HashEntry *new_entries = (HashEntry*) malloc(new_capacity * sizeof(HashEntry));
    if (new_entries == NULL) {
        printf("Memory allocation failed");
        exit(EXIT_FAILURE);
    }

    for (size_t i = 0; i < map->capacity; i++) {
        HashEntry entry = map->entries[i];
        if (entry.dbEntry != NULL) {
            insertEntry(new_entries, new_capacity, entry.variant, entry.dbEntry, NULL);
        }
    }

    free(map->entries);
    map->entries = new_entries;
    map->capacity = new_capacity;
}

void insertHashMap(HashMap *map, Variant variant, const char *dbEntry) {
    if (dbEntry == NULL) {
        printf("Cannot insert NULL");
        exit(EXIT_FAILURE);
    }

    if (map->size >= map->capacity / 2) {
        extendHashMap(map);
    }

    insertEntry(map->entries, map->capacity, variant, dbEntry, &map->size);
}

const char *findEntry(HashMap *map, Variant variant) {
    uint64_t hash = hashVariant(variant);
    size_t index = (size_t)(hash & (uint64_t)(map->capacity - 1));

    while (map->entries[index].dbEntry != NULL) {
        if (compareVariant(variant, map->entries[index].variant)) {
            return map->entries[index].dbEntry;
        }
        index++;
        if (index == map->capacity) {
            index = 0;
        }
    }

    return NULL;
}

void printMap(HashMap *map) {
    printf("size = %ld, capacity = %ld\n", map->size, map->capacity);
    for (size_t i = 0; i < map->capacity; i++) {
        HashEntry entry = map->entries[i];
        if (entry.dbEntry == NULL) continue;
        printf("(%ld -> %ld) %s", hashVariant(entry.variant), i, entry.dbEntry);
    }
}
