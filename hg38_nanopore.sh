#!/bin/bash

#SBATCH --partition=l40s
#SBATCH --time=5:00:00 # can adjust time here, this is the time for 5 and 6
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=12
#SBATCH --gres=gpu:1
#SBATCH -A hlee308_gpu
#SBATCH --job-name=ONT_6BP_HG38
#SBATCH --output=/home/hliu220/data-hlee308/6bp-seq/old_nanopore/logs/hg38_%j.log
#SBATCH --error=/home/hliu220/data-hlee308/6bp-seq/old_nanopore/logs/hg38_%j.err

# --- 1. 激活你的个人虚拟环境 (提供 samtools, modkit, bgzip, tabix) ---
source /home/hliu220/anaconda3/etc/profile.d/conda.sh
conda activate ont_tools

# --- 2. 定义路径 (确认公共路径和个人路径) ---
# 输入 POD5 所在的公共路径
INPUT_DIR="/home/hliu220/scr4-hlee308/cnorton5/old_nanopore/ONT_HG01_hg19/pod5"
# 你的个人工作目录
WORK_DIR="/home/hliu220/data-hlee308/6bp-seq/old_nanopore"
# 公共参考基因组
REF_HG38="/home/hliu220/data-hlee308/6bp-seq/modc_quantification/reference/hg38/hg38.fa"

# *** 公共 Dorado 软件绝对路径 (保持不变) ***
DORADO_BIN="/home/cnorton5/data_hlee308/cnorton5/usr/bin/dorado-0.9.0-linux-x64/bin/dorado"
MODEL="/home/cnorton5/data_hlee308/cnorton5/usr/bin/dorado-0.9.0-linux-x64/bin/models/dna_r9.4.1_e8_hac@v3.3"

# 创建输出目录
mkdir -p "$WORK_DIR/bam_hg38" "$WORK_DIR/methyl_bed" "$WORK_DIR/logs"

echo "Job started at $(date)"
echo "Using Dorado from: $DORADO_BIN"
echo "Using tools from Conda environment: ont_tools"

# --- 3. 循环处理 6 个样本 ---
#for pod5_file in "$INPUT_DIR"/barcode*_merged.pod5; do
    
#    sample_id=$(basename "$pod5_file" _merged.pod5)
 
for pod5_file in "$INPUT_DIR"/barcode0{5,6}_merged.pod5; do
    
    sample_id=$(basename "$pod5_file" _merged.pod5)

    echo "--------------------------------------------"
    echo "Current Sample: $sample_id"
    
    # A. 调用公共 Dorado 进行计算 (利用 4 块 GPU)
    echo "[Step 1] Basecalling & Alignment..."
    $DORADO_BIN basecaller "$MODEL" "$pod5_file" \
        --reference "$REF_HG38" \
        --modified-bases 5mCG_5hmCG \
        --device "cuda:all" > "$WORK_DIR/bam_hg38/${sample_id}_unsorted.bam"

    # B. 使用你环境里的 samtools 排序
    echo "[Step 2] Sorting BAM..."
    samtools sort -@ 48 -o "$WORK_DIR/bam_hg38/${sample_id}_hg38.sorted.bam" "$WORK_DIR/bam_hg38/${sample_id}_unsorted.bam"
    samtools index -@ 48 "$WORK_DIR/bam_hg38/${sample_id}_hg38.sorted.bam"
    
    # 清理临时文件，释放以 TB 为单位的空间
    rm "$WORK_DIR/bam_hg38/${sample_id}_unsorted.bam"

    # C. 使用你环境里的 modkit 提取甲基化
    echo "[Step 3] Methylation Pileup..."
    modkit pileup "$WORK_DIR/bam_hg38/${sample_id}_hg38.sorted.bam" \
        "$WORK_DIR/methyl_bed/${sample_id}_hg38.bed" \
        --threads 48

    # D. 使用你环境里的 bgzip 和 tabix 处理结果
    echo "[Step 4] Compressing & Indexing..."
    bgzip -f "$WORK_DIR/methyl_bed/${sample_id}_hg38.bed"
    tabix -p bed "$WORK_DIR/methyl_bed/${sample_id}_hg38.bed.gz"

    echo "Sample $sample_id finished at $(date)"
done

echo "All tasks completed!"
