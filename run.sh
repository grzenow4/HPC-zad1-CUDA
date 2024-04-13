#!/bin/bash

if [ "$1" = "index" ]; then
    ./gpugenv -i /home/krzadca/biomatch-data/dbNSFP4.5a_variant_100c_sorted.chr22 output/index
elif [ "$1" = "match" ]; then
    ./gpugenv input/homo_sapiens_GRCh38.vcf output/index path/to/matched/output.tsv
else
    echo "Usage: $0 [index|match]"
    exit 1
fi
