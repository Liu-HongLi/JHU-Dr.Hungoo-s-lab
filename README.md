For nanopore set 1, we have splitted pod5 files in hg19, so we can first use hg38_nanopore.sh and bed_to_bigwig.sh to convert pod5 files into bigwig files (hg38)
For nanopore set 2, we only have a merged pod5 files in hg19, so we need to split the merged pod5 files by using Nanopore_set2_split.txt, then use hg38_nanopore.sh and bed_to_bigwig.sh to convert pod5 files into bigwig files (hg38)
