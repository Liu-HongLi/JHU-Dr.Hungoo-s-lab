#!/bin/bash
#SBATCH --job-name=modkit_bw
#SBATCH --partition=parallel      # 转换 BW 不需要 GPU，parallel 分区即可
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=24        # 给 modkit 足够的线程
#SBATCH --mem=32G
#SBATCH --output=logs/modkit_bw_%j.log


# --- 1. 环境准备 ---
source /home/hliu220/anaconda3/etc/profile.d/conda.sh
conda activate ont_tools         # 确保这个环境里有最新的 modkit

# --- 2. 路径定义 (调整为你目前的路径) ---
BASE_DIR="/home/hliu220/data-hlee308/6bp-seq/old_nanopore"
INPUT_DIR="$BASE_DIR/methyl_bed"
OUTPUT_DIR="$BASE_DIR/tracks"
CHROM_SIZES="$BASE_DIR/methyl_bed/hg38.chrom.sizes" # 确认路径正确

mkdir -p "$OUTPUT_DIR"
mkdir -p "$BASE_DIR/tmp_modkit"

# --- 3. 循环处理 01-04 样本 ---
for i in {01..04}; do
    SAMPLE="barcode${i}"
    BED_GZ="$INPUT_DIR/${SAMPLE}_hg38.bed.gz"
    
    if [ ! -f "$BED_GZ" ]; then
        echo "Skip $SAMPLE: $BED_GZ not found."
        continue
    fi

    echo "Processing $SAMPLE at $(date)"

    # 第一步：数据清洗与排序 (复刻实验室脚本的 awk 逻辑)
    # 这一步非常关键：它确保只有在 chrom.sizes 里的染色体被保留，且进行了标准排序
    zcat "$BED_GZ" | \
    awk 'NR==FNR{a[$1];next} ($1 in a)' "$CHROM_SIZES" - | \
    LC_ALL=C sort -k1,1 -k2,2n > "$BASE_DIR/tmp_modkit/${SAMPLE}.temp.bed"

    # 第二步：调用 modkit 转换 (复刻实验室核心命令)
    # 分别提取 5mC (m) 和 5hmC (h)
    echo "Running modkit toBigWig for $SAMPLE..."
    
    # 5mC (Methylation)
    modkit bedmethyl tobigwig \
        --sizes "$CHROM_SIZES" \
        --mod-codes m \
        --nthreads 24 \
        "$BASE_DIR/tmp_modkit/${SAMPLE}.temp.bed" \
        "$OUTPUT_DIR/${SAMPLE}.mc.bw"

    # 5hmC (Hydroxymethylation) - 如果你 6bp-seq 关注这个的话
    modkit bedmethyl tobigwig \
        --sizes "$CHROM_SIZES" \
        --mod-codes h \
        --nthreads 24 \
        "$BASE_DIR/tmp_modkit/${SAMPLE}.temp.bed" \
        "$OUTPUT_DIR/${SAMPLE}.hmc.bw"

    # 清理中间文件
    rm "$BASE_DIR/tmp_modkit/${SAMPLE}.temp.bed"
    
    echo "$SAMPLE conversion finished."
done

rm -rf "$BASE_DIR/tmp_modkit"
echo "All process completed!"
