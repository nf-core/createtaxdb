# Tutorials

## Convert NCBI assembly_summary file to nf-core/createtaxdb samplesheet

A common source of reference genomes to build taxonomic classification databases is the NCBI suite of databases.

Conveniently, NCBI provides 'assembly summary' tables for different taxonomic groups that contain all the information that is needed for a nf-core/createtaxdb samplesheet.
Using this file as a source of reference FASTAs can provide two primary benefits:

- The genomes will be automatically compatible with NCBI taxonomy files
- They provide URLs that can be directly used by Nextflow to download the genome FASTA files for you

The goals of this tutorial are:

- Use standard terminal commands to convert an NCBI `assembly_summary.txt` file to a nf-core/createtaxdb compatible samplesheet
- Build DNA-based Kraken2 and an Amino Acid-based Kaiju databases with the pipeline using the generated samplesheet

:::info
This tutorial is tested with NCBI assembly_summary files from January 2026.

You may need to modify commands if NCBI changes the format of these files in the future.
:::

### Prerequisites

1. Internet connection
2. A Unix terminal (Linux or macOS)
3. Software installed:
   1. `curl` (tested version: `8.5.0`)
   2. `awk` (tested version: `mawk 1.3.4 20240123`)
   3. `sed` (tested version: `GNU sed 4.9`)
   4. `nextflow` (tested version: `25.10.2`)
   5. A Nextflow compatible environment system (for example `conda`, `singularity`, `docker`) (tested version: `docker 27.2.1, build 9e34c9b`)

### Download, filter, and convert the assembly_summary file

1. Download the assembly_summary file for your taxonomic group of interest.

   As an example, we will use the Genome RefSeq database's fungi assembly summary:

   ```bash
   curl -O https://ftp.ncbi.nlm.nih.gov/genomes/refseq/fungi/assembly_summary.txt
   ```

2. Optionally filter the assembly_summary file to only include certain genomes of interest.

   For example, you might want to only include assemblies built to a "Complete" or "Chromosome" level.
   You could do this with command line tools, or in a spreadsheet program.

   Here is an example with `awk` to filter for:
   - Only "Complete Genome"-level assemblies
   - First three genomes

   ```bash
   awk -F '\t' 'NF>2; $12 == "Complete Genome" {print}' assembly_summary.txt | head -n 4 > assembly_summary_filtered.txt
   ```

3. Simplify the assembly_summary file to only include the columns we need for the nf-core/createtaxdb samplesheet, namely, `# assembly_accession`, `taxid`, `ftp_path`.
   Additionally, replace the first line to have the expected nf-core/createtaxdb samplesheet headers: `id`, `taxid`, `fasta_dna`, `fasta_aa`.

   ```bash
   cut -f 1,7,20 assembly_summary_filtered.txt | sed 's/#assembly_accession.*/id\ttaxid\tfasta_dna\tfasta_aa/' > assembly_summary_simplified.txt
   ```

   This results in:

   ```tsv
   id	taxid	fasta_dna	fasta_aa
   GCF_041956525.1	4840	https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/041/956/525/GCF_041956525.1_Rhipu1
   GCF_000002945.2	4896	https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/945/GCF_000002945.2_ASM294v3
   GCF_003054445.1	4909	https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/054/445/GCF_003054445.1_ASM305444v1
   ```

4. Reconstruct the complete URLs of the relevant FASTA files to make them downloadable.

   ```bash
   awk 'BEGIN { FS=OFS="\t" } NR > 1 { n=split($3,p,"/"); $4=$3"/"p[n]"_protein.faa.gz"; $3=$3"/"p[n]"_genomic.fna.gz"} {print $1","$2","$3","$4}' assembly_summary_simplified.txt > samplesheet.csv
   ```

   :::info{collapse="true" title="Explanation of `awk` command"}
   This `awk` command works as follows:
   1. Specify tab as the delimiter
   2. Print the header line
   3. Extract the base URL column and in the variable `n`, split the elements on `/` into an array called `p`
   4. Construct a new protein FASTA URL column based on base URL, but append the last element of the array `p` (called by the length of `n`) plus `_protein.faa.gz`
   5. Replace the existing base URL column with a new DNA FASTA URL constructed in the same way as the protein FASTA URL, but instead append `_genomic.fna.gz`
   6. Print the four columns, separated by commas to create the expected nf-core/createtaxdb CSV file

   :::

   This results in:

   ```tsv
   id,taxid,fasta_dna,fasta_aa
   GCF_041956525.1,4840,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/041/956/525/GCF_041956525.1_Rhipu1/GCF_041956525.1_Rhipu1_genomic.fna.gz,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/041/956/525/GCF_041956525.1_Rhipu1/GCF_041956525.1_Rhipu1_protein.faa.gz
   GCF_000002945.2,4896,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/945/GCF_000002945.2_ASM294v3/GCF_000002945.2_ASM294v3_genomic.fna.gz,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/945/GCF_000002945.2_ASM294v3/GCF_000002945.2_ASM294v3_protein.faa.gz
   GCF_003054445.1,4909,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/054/445/GCF_003054445.1_ASM305444v1/GCF_003054445.1_ASM305444v1_genomic.fna.gz,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/054/445/GCF_003054445.1_ASM305444v1/GCF_003054445.1_ASM305444v1_protein.faa.gz
   ```

   :::tip
   If you only want to build DNA-based databases (for example, Kraken2), omit the `$4` variable definition and printing.

   ```bash
   awk 'BEGIN { FS=OFS="\t" } NR > 1 { n=split($3,p,"/"); $3=$3"/"p[n]"_genomic.fna.gz"} {print $1","$2","$3}' assembly_summary_simplified.txt > samplesheet_dna.csv
   ```

   This results in:

   ```csv
   id,taxid,fasta_dna
   GCF_041956525.1,4840,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/041/956/525/GCF_041956525.1_Rhipu1/GCF_041956525.1_Rhipu1_genomic.fna.gz
   GCF_000002945.2,4896,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/945/GCF_000002945.2_ASM294v3/GCF_000002945.2_ASM294v3_genomic.fna.gz
   GCF_003054445.1,4909,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/054/445/GCF_003054445.1_ASM305444v1/GCF_003054445.1_ASM305444v1_genomic.fna.gz
   ```

   If you only want to build amino acid-based databases (for example, Kaiju), omit the `$4` variable definition and printing, and replace the `$3` field with `_protein.faa.gz`.
   You will also need to replace the header:

   ```bash
   awk 'BEGIN { FS=OFS="\t" } NR > 1 { n=split($3,p,"/"); $3=$3"/"p[n]"_protein.faa.gz"} {print $1","$2","$3}' assembly_summary_simplified.txt > samplesheet_aa.csv
   sed -i '1s/fasta_dna/fasta_aa/' samplesheet_aa.csv
   ```

   This results in:

   ```csv
   id,taxid,fasta_aa
   GCF_041956525.1,4840,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/041/956/525/GCF_041956525.1_Rhipu1/GCF_041956525.1_Rhipu1_protein.faa.gz
   GCF_000002945.2,4896,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/945/GCF_000002945.2_ASM294v3/GCF_000002945.2_ASM294v3_protein.faa.gz
   GCF_003054445.1,4909,https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/054/445/GCF_003054445.1_ASM305444v1/GCF_003054445.1_ASM305444v1_protein.faa.gz
   ```

   :::

### Download taxonomy files

- Download the necessary NCBI taxonomy files required by Kraken2 with:

  ```bash
  curl -O https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdmp.zip
  unzip taxdmp.zip
  rm taxdmp.zip
  curl -O https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
  gunzip nucl_gb.accession2taxid.gz
  ```

- Kaiju does not require taxonomy files for database construction.

### Run the pipeline

- Run the nf-core/createtaxdb pipeline to build our databases as [normal](../usage.md).
  Specify the samplesheet and taxonomy files we created and downloaded with their respective parameters.
  Here we use `docker` as our environment manager:

  ```bash
  nextflow run nf-core/createtaxdb \
  -r 2.0.0 \
  -profile docker \
  --input samplesheet.csv \
  --outdir ./results \
  --dbname ncbi_fungi \
  --nodesdmp nodes.dmp \
  --namesdmp names.dmp \
  --accession2taxid nucl_gb.accession2taxid \
  --build_kraken2 --build_kaiju
  ```

:::note
By default the pipeline assumes you need 72 GB of RAM to build a Kraken2 database.
However, the test run can fit within approximately 8 GB of RAM due to the small number of genomes.

If running on a smaller machine, you may get an error such as `Process requirement exceeds available memory -- req: 36 GB; avail: 31 GB`.
To create a custom config file (for example, `custom_config.config`) with the following contents to reduce the memory requirement.
In this case, my machine has 16GB RAM:

```groovy
process {
    resourceLimits = [
        cpus: 4,
        memory: '15.GB',
        time: '1.h',
    ]
}
```

Append to the end of the Nextflow command the parameter `-c custom_config.config`.
:::

Once completed successfully, you can check the database files in the `results/` directory with

```bash
ls results/{kaiju,kraken2}/*
```

And we can see the Kaiju `.fmi` file and the Kraken2 database directory:

```bash
results/kaiju/ncbi_fungi-kaiju.fmi

results/kraken2/ncbi_fungi-kraken2:
hash.k2d  opts.k2d  taxo.k2d
```

### Bonus: NCBI assembly_summary to samplesheet one-liner

In fact, we can execute all the commands to generate the samplesheet described [above](#convert-ncbi-assembly_summary-file-to-nf-corecreatetaxdb-samplesheet) in one go as single UNIX one-liner command:

```bash
awk -F '\t' 'NF>2; $12 == "Complete Genome" {print}' assembly_summary.txt $(curl https://ftp.ncbi.nlm.nih.gov/genomes/refseq/fungi/assembly_summary.txt) | \
head -n 4 | cut -f 1,7,20 | \
sed 's/#assembly_accession.*/id\ttaxid\tfasta_dna\tfasta_aa/' | \
awk 'BEGIN { FS=OFS="\t" } NR > 1 { n=split($3,p,"/"); $4=$3"/"p[n]"_protein.faa.gz"; $3=$3"/"p[n]"_genomic.fna.gz"} {print $1","$2","$3","$4}' > samplesheet.csv
```

:::info
We have to place the `curl` command within the `awk` command substitution `$()` to ensure the file is completely downloaded before the rest of the pipe starts processing.
:::

### Summary

In this tutorial we went through how to convert an NCBI assembly_summary file to a nf-core/createtaxdb samplesheet.

We used standard command line tools to download, filter, and reformat the assembly_summary file in a reproducible manner and use this file to generate databases for two different taxonomic classification tools with nf-core/createtaxdb.

Use these steps to quickly build custom taxonomic classification databases for your metagenomic analyses from one of the most popular source of reference genomes.

_Note: The `awk` command in step 4 was partly written with the assistance of AI (Claude Haiku 4.5). Documentation style review with GPT-5.1-Codex-Max_
