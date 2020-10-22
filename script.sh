#!/bin/bash

#cd ~/Assignment1/fastq
mkdir fastqc_result

# Raw data quality check and put uncompressed output files in a directory
fastqc -t 64 -extract -outdir fastqc_result *.fq.gz

# Find the paths for fastqc output files
cd ~/Assignment1/fastq/fastqc_result
find -type f -name fastqc_data* > output.list
find -type f -name summary* >> output.list
sort -o output.list output.list

# Extract sequence numbers and quality details 
for i in `cat output.list`;
do 
	cat $i|grep -m1 -i filename
	cat $i|grep -m1 -i total
	cat $i|grep -m1 "Sequence length"
	cat $i|grep -m1 -i flag
	cat $i|cut -f 1,2 |awk '{FS="\t"; if ($1 =="FAIL"||$1 =="WARN"&&$1 !="PASS"){print $0}}'
	echo ------------;
done >> file1 # save the information in file1
cat file1 #show results on screen

# Format conversion from .fq to .fa
# Not sure if needed
#cd ~/Assignment1/fastq
#for fq in *.fq.gz
#do /localdisk/home/s1544765/seqtk/seqtk seq -a $fq> $fq\.fa
#done

# Prepare reference genome for alignment
cd /localdisk/data/BPSM/Assignment1/Tbb_genome/
cp Tb927_genome.fasta.gz ~/Assignment1/fastq
cd ~/Assignment1/fastq

# Make indexed reference using bowtie2
mkdir reference_index
gunzip Tb927_genome.fasta.gz
bowtie2-build --threads 64 Tb927_genome.fasta reference_index/

# Prepare sequence lists for pair-ended alignment
find -type f -name "*_1*.gz"|sort > odd.list
find -type f -name "*_2*.gz"|sort > even.list
gene_pair_number=$(< "odd.list" wc -l)

# Pair-ended alignment of gene pairs with reference genome
for number in $(seq $gene_pair_number);
do 
	sq1=$(sed -n $number\p odd.list)
	sq2=$(sed -n $number\p even.list)
	echo -e "start pair-ended alignment of $sq1 and $sq2"
	bowtie2 --threads 64 -x reference_index/ -1 $sq1 -2 $sq2 -S gene_pair$number\.sam	#alignment
	echo -e "Done alighnment of gene pair $number"
	samtools view -b -h -o gene_pair$number\.bam gene_pair$number\.sam	#convert sam file into bam
	samtools sort gene_pair$number\.bam > gene_pair$number\.srt.bam		#sort bam file
	samtools index gene_pair$number\.srt.bam	#index bam
	echo -e "SAM->BAM->INDEXED SORT BAM created for gene pair $number"
-----------
done

# Prepare the file with gene location information
cd /localdisk/data/BPSM/Assignment1/
cp Tbbgenes.bed ~/Assignment1/fastq
cd ~/Assignment1/fastq

# Prepare a file for mean count
echo -e "Gene\tSlender_216\tSlender_218\tSlender_219\tStumpy_220\tStumpy_221\tStumpy_222" > count_mean.txt	#add head

# Generate number of reads
for number in $(seq $gene_pair_number);
do
        bedtools bamtobed -i gene_pair$number\.srt.bam > gene_pair$number\.bed		#sorted	bam to bed 
        bedtools coverage -a Tbbgenes.bed -b gene_pair$number\.bed -mean |cut -f 4,7 > count$number.txt		#output in seperate files
done
