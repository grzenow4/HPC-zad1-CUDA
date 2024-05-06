# Matching in genome variant databases - CUDA Assignment

## Introduction
A reference genome of a species contains its most common DNA sequence — it might be interpreted as an "average" genome. When analyzing the DNA sequence of a certain individual, one of diagnostic methods is to compute the difference between the individual and the reference sequence; the resulting list of variants is matched to a database that maps some of these variants to, e.g., frequencies in population or clinical data. Bioinformatics has standard, perl-based tools for such mappings (vep is the reference). The goal of this assigment is to explore whether massive parallelization and broader memory bandwidth of a modern GPU convincingly speeds-up the process.

This assignment is done in collaboration with Przemyslaw Lyszkiewicz (Genomed).

## Matching in genome variant databases
Your goal is to implement variant matching between a genome variant database and a genome variant. We will simulate the diagnostic process that matches many (thousands) of genome variants to the same database.

## Input and output
Programs will be tested automatically. Please stick to the format below.

Your program will be run using the following instructions:

Your program will be run in two phases. First, it will have up to 3 minutes to index the database:
```bash
~mkdir build-xx123456; cp -r xx123456/* build-xx123456; cd build-xx123456; make~
./gpugenv -i path/to/dbNSFP.tsv path/to/your/output/index
```

We will work on a subset of dbNSFP (as the whole database is over 39GB compressed), but you must make sure that your program works correctly with the whole database (but: you don't have to assume it will index the whole database in 3 minutes). The subset will be sorted by the first two columns (chromosome: 1-22, then N,X,Y; and position).

We publish an example subset of dbNSFP (chromosome 22, only the first 100 columns) at entropy: `/home/krzadca/biomatch-data/dbNSFP4.5a_variant_100c_sorted.chr22`.

As indexing is done once, we do not assume you will heavily optimize this part (beyond making sure indexing finishes on entropy GPUs in the given time).

Then, it will match variants from `variant.vcf` to the (indexed) database:
```bash
./gpugenv path/to/variant.vcf path/to/your/output/index path/to/matched/output.tsv
```

`output.tsv` must contain the lines from the dbNSFP that describe variants in `variant.vcf`. Matching is done on chromosome (CHROM), position (POS), reference (REF) and alternative (ALT). `variant.vcf` is not sorted. `variant.vcf` may contantain the same line multiple times - in which case you have produce as many matches as there are redundant lines. `output.tsv` does not have to be sorted. You may assume that REF and ALT contain only A,C,G,T (they do not contain a dot). You may assume only line in the dbNSFP matches one line from the input.

Example `homo_sapiens_GRCh38.vcf` (a fragment: first few lines): (source: https://raw.githubusercontent.com/Ensembl/ensembl-vep/release/111/examples/homo_sapiens_GRCh38.vcf)
```
##fileformat=VCFv4.0
#CHROM  POS ID  REF ALT QUAL    FILTER  INFO
22  17181903    rs7289170   A   G   .   .   .
22  17188416    rs2231495   T   C   .   .   .
22  19353405    rs34000365  G   A   .   .   .
22  19378003    rs115877869 G   C   .   .   .
22  19383643    rs61735928  G   A   .   .   .
22  19385577    rs115157927 A   T   .   .   .
22  19396832    rs9618556   C   T   .   .   .
```

Example `dbNSFP.tsv` (a fragment, first few lines, first 100 columns):
```
#chr    pos(1-based)    ref alt aaref   aaalt   rs_dbSNP    hg19_chr    hg19_pos(1-based)   hg18_chr    hg18_pos(1-based)   aapos   genename    Ensembl_geneid  Ensembl_transcriptid    Ensembl_proteinid   Uniprot_acc Uniprot_entry   HGVSc_ANNOVAR   HGVSp_ANNOVAR   HGVSc_snpEff    HGVSp_snpEff    HGVSc_VEP   HGVSp_VEP   APPRIS  GENCODE_basic   TSL VEP_canonical   cds_strand  refcodon    codonpos    codon_degeneracy    Ancestral_allele    AltaiNeandertal Denisova    VindijiaNeandertal  ChagyrskayaNeandertal   SIFT_score  SIFT_converted_rankscore    SIFT_pred   SIFT4G_score    SIFT4G_converted_rankscore  SIFT4G_pred Polyphen2_HDIV_score    Polyphen2_HDIV_rankscore    Polyphen2_HDIV_pred Polyphen2_HVAR_score    Polyphen2_HVAR_rankscore    Polyphen2_HVAR_pred LRT_score   LRT_converted_rankscore LRT_pred    LRT_Omega   MutationTaster_score    MutationTaster_converted_rankscore  MutationTaster_pred MutationTaster_model    MutationTaster_AAE  MutationAssessor_score  MutationAssessor_rankscore  MutationAssessor_pred   FATHMM_score    FATHMM_converted_rankscore  FATHMM_pred PROVEAN_score   PROVEAN_converted_rankscore PROVEAN_pred    VEST4_score VEST4_rankscore MetaSVM_score   MetaSVM_rankscore   MetaSVM_pred    MetaLR_score    MetaLR_rankscore    MetaLR_pred Reliability_index   MetaRNN_score   MetaRNN_rankscore   MetaRNN_pred    M-CAP_score M-CAP_rankscore M-CAP_pred  REVEL_score REVEL_rankscore MutPred_score   MutPred_rankscore   MutPred_protID  MutPred_AAchange    MutPred_Top5features    MVP_score   MVP_rankscore   gMVP_score  gMVP_rankscore  MPC_score   MPC_rankscore   PrimateAI_score PrimateAI_rankscore PrimateAI_pred  DEOGEN2_score   DEOGEN2_rankscore
22  15528159    A   C   M   L   .   14  19377594    14  18447594    1   OR11H1  ENSG00000130538 ENST00000252835 ENSP00000252835 Q8NG94  O11H1_HUMAN c.1A>C  p.M1L   c.1A>C  p.Met1? c.1A>C  p.Met1? principal2  Y   NA  YES +   ATG 1   0   a   ./. ./. ./. ./. 0.074   0.34621 T   1.0 0.01155 T   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   9.98    0.00000 T   -0.09   0.08340 N   0.142   0.14196 -1.2082 0.00098 T   0.0001  0.00039 T   6   0.70042473  0.72408 D   0.131865    0.81414 D   .   .   0.974;  0.99756 B2RN74; M1L;    Gain of catalytic residue at C2 (P = 5e-04);    0.514569622772  0.51098 0.18503497278141268 0.18421 .   .   .   .   .   1.08E-4 0.00011
22  15528159    A   G   M   V   .   14  19377594    14  18447594    1   OR11H1  ENSG00000130538 ENST00000252835 ENSP00000252835 Q8NG94  O11H1_HUMAN c.1A>G  p.M1V   c.1A>G  p.Met1? c.1A>G  p.Met1? principal2  Y   NA  YES +   ATG 1   0   a   ./. ./. ./. ./. 0.175   0.22400 T   0.505   0.11004 T   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   9.95    0.00000 T   0.02    0.06739 N   0.163   0.17140 -1.1460 0.01149 T   0.0001  0.00039 T   6   0.66618246  0.70440 D   0.038606    0.58323 D   .   .   0.971;  0.99725 B2RN74; M1V;    Gain of catalytic residue at C2 (P = 9e-04);    0.412176505671  0.40830 0.2756480215030847  0.27477 .   .   .   .   .   1.08E-4 0.00011
22  15528159    A   T   M   L   .   14  19377594    14  18447594    1   OR11H1  ENSG00000130538 ENST00000252835 ENSP00000252835 Q8NG94  O11H1_HUMAN c.1A>T  p.M1L   c.1A>T  p.Met1? c.1A>T  p.Met1? principal2  Y   NA  YES +   ATG 1   0   a   ./. ./. ./. ./. 0.074   0.34621 T   1.0 0.01155 T   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   9.98    0.00000 T   -0.09   0.08340 N   0.142   0.14196 -1.2082 0.00098 T   0.0001  0.00039 T   6   0.7008989   0.72437 D   0.131865    0.81414 D   .   .   0.974;  0.99756 B2RN74; M1L;    Gain of catalytic residue at C2 (P = 5e-04);    0.513042017857  0.50944 0.1850350003234816  0.18421 .   .   .   .   .   1.08E-4 0.00011
22  15528160    T   A   M   K   rs1985997621    14  19377595    14  18447595    1   OR11H1  ENSG00000130538 ENST00000252835 ENSP00000252835 Q8NG94  O11H1_HUMAN c.2T>A  p.M1K   c.2T>A  p.Met1? c.2T>A  p.Met1? principal2  Y   NA  YES +   ATG 2   0   t   ./. ./. ./. ./. 0.003   0.68238 D   0.022   0.57587 D   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   9.89    0.00001 T   -0.9    0.24244 N   0.207   0.22998 -1.1460 0.01149 T   0.0001  0.00039 T   5   0.69784814  0.72256 D   0.074281    0.72002 D   .   .   0.954;  0.99484 B2RN74; M1K;    Gain of catalytic residue at C2 (P = 9e-04);    0.333849504488  0.32989 0.551786760048235   0.55104 .   .   .   .   .   7.74E-4 0.00369
22  15528160    T   C   M   T   .   14  19377595    14  18447595    1   OR11H1  ENSG00000130538 ENST00000252835 ENSP00000252835 Q8NG94  O11H1_HUMAN c.2T>C  p.M1T   c.2T>C  p.Met1? c.2T>C  p.Met1? principal2  Y   NA  YES +   ATG 2   0   t   ./. ./. ./. ./. 0.011   0.55530 D   0.042   0.50226 D   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   9.88    0.00001 T   -0.34   0.12661 N   0.073   0.04668 -1.1466 0.01130 T   0.0001  0.00039 T   5   0.6270479   0.68302 D   0.038474    0.58245 D   .   .   0.977;  0.99785 B2RN74; M1T;    Gain of catalytic residue at C2 (P = 0.0011);   0.289831133145  0.28582 0.34105357722863605 0.34018 .   .   .   .   .   1.08E-4 0.00011
22  15528160    T   G   M   R   .   14  19377595    14  18447595    1   OR11H1  ENSG00000130538 ENST00000252835 ENSP00000252835 Q8NG94  O11H1_HUMAN c.2T>G  p.M1R   c.2T>G  p.Met1? c.2T>G  p.Met1? principal2  Y   NA  YES +   ATG 2   0   t   ./. ./. ./. ./. 0.003   0.68238 D   0.022   0.57587 D   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   9.87    0.00001 T   -0.98   0.25986 N   0.228   0.25622 -1.1460 0.01149 T   0.0001  0.00039 T   5   0.7291183   0.74176 D   0.07072 0.71078 D   .   .   0.976;  0.99776 B2RN74; M1R;    Gain of catalytic residue at C2 (P = 2e-04);    0.408543089712  0.40467 0.49350339055262415 0.49271 .   .   .   .   .   0.001194    0.00692
```

Example result when run on the 7 lines of `homo_sapiens` above (the remaining variants are not in the database; the result contains the whole lines from entropy: `/home/krzadca/biomatch-data/dbNSFP4.5a_variant_100c_sorted.chr22`):
```
22  17188416    T   C   H   R   rs2231495   22  17669306    22  16049306    215;335;335;94;335;335;293;293  ADA2;ADA2;ADA2;ADA2;ADA2;ADA2;ADA2;ADA2 ENSG00000093072;ENSG00000093072;ENSG00000093072;ENSG00000093072;ENSG00000093072;ENSG00000093072;ENSG00000093072;ENSG00000093072 ENST00000610390;ENST00000399837;ENST00000399839;ENST00000330232;ENST00000262607;ENST00000647714;ENST00000449907;ENST00000649540 ENSP00000483418;ENSP00000382731;ENSP00000382733;ENSP00000332871;ENSP00000262607;ENSP00000497821;ENSP00000406443;ENSP00000497469 A0A087X0I3;Q9NZK5;Q9NZK5;Q9NZK5-2;Q9NZK5;Q9NZK5;B4E3Q4;B4E3Q4   A0A087X0I3_HUMAN;ADA2_HUMAN;ADA2_HUMAN;ADA2_HUMAN;ADA2_HUMAN;ADA2_HUMAN;B4E3Q4_HUMAN;B4E3Q4_HUMAN   c.644A>G;c.1004A>G;c.1004A>G;c.281A>G;c.1004A>G;.;c.878A>G;.    p.H215R;p.H335R;p.H335R;p.H94R;p.H335R;.;p.H293R;.  c.644A>G;c.1004A>G;c.1004A>G;c.281A>G;c.1004A>G;.;c.878A>G;.    p.His215Arg;p.His335Arg;p.His335Arg;p.His94Arg;p.His335Arg;.;p.His293Arg;.  c.644A>G;c.1004A>G;c.1004A>G;c.281A>G;c.1004A>G;c.1004A>G;c.878A>G;c.878A>G p.His215Arg;p.His335Arg;p.His335Arg;p.His94Arg;p.His335Arg;p.His335Arg;p.His293Arg;p.His293Arg  .;principal3;principal3;.;principal3;principal3;alternative2;alternative2   Y;Y;Y;Y;Y;Y;Y;Y 5;1;5;2;1;.;2;. .;.;YES;.;.;.;.;.   -;-;-;-;-;-;-;- CAT;CAT;CAT;CAT;CAT;CAT;CAT;CAT 2;2;2;2;2;2;2;2 0;0;0;0;0;0;0;0 T   T/T T/T T/T T/T .;0.312;0.312;0.356;0.312;.;0.312;. 0.13925 .;T;T;T;T;.;T;. 0.343;0.34;0.34;0.349;0.34;.;0.342;.    0.18018 T;T;T;T;T;.;T;. .;0.237;0.237;0.001;0.237;0.237;.;. 0.30795 .;B;B;B;B;B;.;. .;0.015;0.015;0.0;0.015;0.015;.;.   0.17295 .;B;B;B;B;B;.;. 0.005837    0.32475 N   0.345183    1;1;1;1;0.999987    0.18198 P;P;P;P;P   simple_aae;simple_aae;simple_aae;simple_aae;simple_aae  H335R;H335R;H94R;H335R;H293R    .;.;.;.;.;.;.;. .   .;.;.;.;.;.;.;. .;-1.54;-1.54;-1.54;-1.54;.;-1.54;. 0.81640 .;D;D;D;D;.;D;. .;-1.16;-1.16;-1.09;-1.16;.;-1.16;. 0.29727 .;N;N;N;N;.;N;. 0.087;0.064;0.099;0.097;0.064;.;0.126;. 0.11912 -0.9192 0.45662 T   0.0000  0.00011 T   9   8.136581e-05;8.136581e-05;8.136581e-05;8.136581e-05;8.136581e-05;8.136581e-05;8.1365884e-05;8.1365884e-05   0.00009 T;T;T;T;T;T;T;T .   .   .   .;0.176;0.176;0.176;0.176;.;0.176;. 0.44373 .;.;.;.;.;.;.;.;    .   .;.;.;.;.;.;.;.;    .;.;.;.;.;.;.;.;    .;.;.;.;.;.;.;.;    .;.;.;.;.;.;.;. .   .;0.3789504863282134;.;.;.;.;.;.    0.37810 .;.;0.0507776018214;.;.;.;.;.   0.05576 0.380416631699  0.22316 T   0.004945;0.227596;0.227596;.;0.227596;0.227596;.;.  0.59293
22  19385577    A   T   S   T   rs115157927 22  19373100    22  17753100    425;425 HIRA;HIRA   ENSG00000100084;ENSG00000100084 ENST00000340170;ENST00000263208 ENSP00000345350;ENSP00000263208 P54198-2;P54198 HIRA_HUMAN;HIRA_HUMAN   c.1273T>A;c.1273T>A p.S425T;p.S425T c.1273T>A;c.1273T>A p.Ser425Thr;p.Ser425Thr c.1273T>A;c.1273T>A p.Ser425Thr;p.Ser425Thr .;principal1    Y;Y 1;1 .;YES   -;- TCA;TCA 1;1 0;0 A   A/A A/A A/A A/A 0.451;0.411 0.10115 T;T 0.8;0.812   0.04066 T;T 0.0;0.018   0.17786 B;B 0.002;0.009 0.14300 B;B 0.024598    0.26236 N   0.400737    0.820145;0.820145;0.777882;0.777882 0.34764 D;D;D;D simple_aae;simple_aae;simple_aae;simple_aae S425T;S425T;S381T;S381T 0.55;0.55   0.14455 N;N -0.35;-0.6  0.71662 T;T -0.24;-0.26 0.11185 N;N 0.111;0.103 0.09772 -1.0272 0.21363 T   0.1225  0.42441 T   10  0.019130021;0.019130021 0.00423 T;T 0.015063    0.35570 T   0.065;0.065 0.18881 .;.;    .   .;.;    .;.;    .;.;    0.523447128704;0.523447128704   0.51990 .;0.4181471056604377    0.41730 .;1.08006191303 0.77111 0.390007972717  0.23670 T   .;0.229962  0.59592
```

## Specific requirements
Your goal is to optimize the matching of `variant.vcf` to the indexed database. Consider this as a throughput-oriented computation: `variant.vcf` could contain thousands to milions of lines.

This is a somewhat experimental assignment. The key element - searching in an index - is fairly simple. Your goal is to test, benchmark and describe variants of your code. Consider how to divide work between the GPU and the CPU; how to use, e.g., shared memory, etc.

## Solution content
We will score your code and your report.

Please send us a single `.zip` file that after unziping has least the following files in the path where the file is unzipped (not in subdirectories)
- `Makefile`: please make sure your code compiles with `make` on entropy.
- source code of your implementation.
- `report.pdf`: your report.

The report should contain:
- a description of your implementation: what is parallelized? which optimizations you consider?
- quality tests: why do you think your implementation is correct?
- performance tests: how fast is your program? what is the influence of the optimizations you did? Do the performance tests on entropy, but make sure that any single run completes in 2-3 minutes.

## Scoring
- report: 8 points
- correctness: 8 points
- performance & variants considered: 9 points

We will score correctness on our test data. If your solution passes most of the tests, but fails on some, we will contact you and you will be able to submit a patched version.

We will use entropy's RTX 2080 for performance testing.

## Additional reading
Please do not use any source codes of GPU implementations of indexing or hashing. For addtional information and bioinfomatics context, we recommmend reading the following:

- https://github.com/Ensembl/ensembl-vep.git - `vep`, the reference implementation of a generic tool that matches a variant to a number of databases
- https://link.springer.com/article/10.1186/s13073-020-00803-9 a paper describing dbNSFP
- https://en.wikipedia.org/wiki/Variant_Call_Format described the `vcf` file format
- https://academic.oup.com/bioinformatics/article/27/5/718/262743 describes `tabix`, a format and a tool used by `vep` to match `vcf` to dbNSFP
- https://academic.oup.com/gigascience/article/10/2/giab008/6137722 describes (non-GPU) tools that are used to process bioinfomatics files
