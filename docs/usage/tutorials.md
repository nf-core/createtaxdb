# nf-core/createtaxdb: Tutorials

This page provides a range of tutorials to help give you a more step-by-step guidance on how to set up and run nf-core/createtaxdb in different contexts.

## Linking different nf-core pipelines together

nf-core/createtaxdb can be used to generate input database sheets for pipelines such as [nf-core/taxprofiler](https://nf-co.re/taxprofiler).
This tutorial will guide you step-by-step on how to setup a nf-core/createtaxdb run so that you can then run nf-core/taxprofiler almost straight away after.

### Prerequisites

#### Hardware

The datasets provided here _should_ be small enough to run on your laptop or desktop computer.
It should not require a HPC or similar.

If you wish to use a HPC cluster or cloud, and don’t wish to use an ‘interactive’ session submitted to your scheduler, please see the [nf-core documentation](https://nf-co.re/docs/usage/configuration#introduction) on how to make a relevant config file.

You will need internet access and at least X.X GB of hard-drive space.

##### Software

The tutorial assumes you are on a Unix based operating system, and have already installed Nextflow as well a software environment system such as [Conda](https://docs.conda.io/en/latest/miniconda.html), [Docker](https://www.docker.com/), or [Singularity/Apptainer](https://apptainer.org/).
The tutorial will use Docker, however you can simply replace references to `docker` with `conda`, `singularity`, or `apptainer` accordingly.

It also assumes you've already pulled both nf-core/createtaxdb and nf-core/taxprofiler pipelines with `nextflow pull`.

#### Data

First we will make a directory to run the whole tutorial in.

```bash
mkdir createtaxdb-tutorial
cd createtaxdb-tutorial/
```

##### nf-core/createtaxdb

First we will need to download some reference genome FASTAs for building into databases for nf-core/createtaxdb.
These species are present in our sequencing reads we will use for nf-core/taxprofiler.

```bash
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/refs/heads/createtaxdb/data/tutorials/GCF_015533775.1_ASM1553377v1_genomic.fna.gz # P. roqueforti
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/refs/heads/createtaxdb/data/tutorials/NC_012920.1.fa.gz # H. sapiens mitochondrial genome
```

We will also need some taxonomy files.
We have prepared for you the relevant files with just the taxonomy and accession IDs of the species of interest (rather than the very large whole NCBI taxonomy)

```bash
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/refs/heads/createtaxdb/data/tutorials/taxonomy/nucl_gb.accession2taxid
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/refs/heads/createtaxdb/data/tutorials/names_reduced.dmp
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/refs/heads/createtaxdb/data/tutorials/nodes_reduced.dmp
```

##### nf-core/taxprofiler

Then, for aligning against our database, we will use very small short-read (pre-subset) metagenomes used for testing.
We will download two sets of paired-end sequencing reads.

```bash
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_1.fastq.gz
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_2.fastq.gz
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_B_1.fastq.gz
curl -O https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_B_2.fastq.gz
```

### Configuration

For the purposes of this tutorial, we will tell the nf-core pipelines to a tiny amount of computational resources, to ensure it can run on your machine.

For this we will make a custom configuration file called `tutorial.conf` with the following contents:

```
process {
    resourceLimits = [
        cpus: 4,
        memory: '15.GB',
        time: '1.h'
    ]
}
```

### Running nf-core/createtaxdb

#### Input nf-core/createtaxdb samplesheet preparation

To generate our database files from our FASTA files with nf-core/createtaxdb, we first write the createtaxdb samplesheet.
In this case we wil make a file called `input.csv` in a text editor which will contain the following:

```csv
id,taxid,fasta_dna,fasta_aa
Penicillium_roqueforti,5082,GCF_015533775.1_ASM1553377v1_genomic.fna.gz,
Homo_sapiens,9606,NC_012920.1.fa.gz,
```

We won't generate amino-acid based databases, so we just supply our two downloaded nucleotide reference genomes. and leave the `fasta_aa` column blank.

#### Prepare and run nf-core/createtaxdb command

Then we can construct a nf-core/createtaxdb command.
In this example, we will create two databases, one for `kraken2`, and one for a`centrifuge`.
We will supply the input files of the `input.csv`, and the three taxdmp related files: `nodes_reduced.dmp`, `names_reduced.dmp`, and `nucl_gb.accession2taxid`.
We will also specify the name of the database to build, and also the two tools to generate databases for.

```bash
## TODO  add comment about picking correct profile, remove `-r dev`; Currently not working, the nucl_gb.accession2taxid isn't working
## TODO remove and use roper pipeline name not ../main
## TODO Maybe fix kraken2 add  module to always stage the accession2taxid as taxonomy/nucl_gb.accession2taxid (not just the directory)
nextflow run ../main.nf \
  -profile docker \
  -c tutorial.conf \
  --input input.csv \
  --nodesdmp nodes_reduced.dmp \
  --namesdmp names_reduced.dmp \
  --accession2taxid nucl_gb.accession2taxid \
  --nucl2taxid nucl2taxid.txt \
  --outdir createtaxdb_results \
  --dbname tutorial \
  --build_kraken2 \
  --build_centrifuge \
  --generate_tar_archive \
  --generate_downstream_samplesheets \
  --generate_pipeline_samplesheets 'taxprofiler' \
  --generate_samplesheet_dbtype 'tar'
```

After the input and output files, we also specify a name for the databases to created, to build the two databases of interest for the two tools, and also tell the pipeline to generate `.tar.gz` archives of the generated databases, and to generate the samplesheet for `taxprofiler`.

Generating the `.tar.gz` files is optional, as nf-core/taxprofiler can accept directories - however this can be useful for cloud contexts where you cannot 'download' directories.
If we want to supply just the raw database output (i.e., no `tar` archives), we would specify `--generate_samplesheet_dbtype 'raw'.

Currently, nf-core/createtaxdb only supports generating a single pipeline samplesheet.
However in the future, when this is extended to other pipelines, you can supply a comma separated list to make samplesheets for multiple pipelines at once! For example with `--generate_pipeline_samplesheets 'taxprofiler,ampliseq'`.

Now we have a better understanding of what the command is doing, we can execute it, and the pipeline should run!

#### nf-core/createtaxdb output

Once the run finishes, we can look in the specified `--outdir` directory, for a subdirectory called `downstream_samplesheets`.
In this tutorial this is `createtaxdb_results/downstream_samplesheets`.

This samplesheet, called `databases-taxprofiler.csv`, can be used used as input to nf-core/taxprofiler!

It should look something like this:

```csv title="databases-taxprofiler.csv"
tool,db_name,db_params,db_path
kraken2,tutorial-kraken2,,/<path>/<to>/createtaxdb_results/kraken2/tutorial-kraken2.tar.gz
centrifuge,tutorial-centrifuge,,/<path>/<to>/createtaxdb_results/centrifuge/tutorial-centrifuge.tar.gz
```

Note that paths to the databases in this `.csv` file point to the nf-core/createtaxdb results run directory, make sure not to move or delete them!

### Running nf-core/taxprofiler

Now with our downloaded reads files that we prepared during the preparation section of this tutorial, and our database samplesheet we can run nf-core/taxprofiler!

#### Input nf-core/taxprofiler samplesheet preparation

Firstly we prepare an input _samplesheet_ (not database sheet!) with our reads and their metadata.

Open a text editor, and create a file called `samplesheet.csv`.
Copy and paste the following lines into the file and save it.

```csv title="samplesheet.csv"
sample,run_accession,instrument_platform,fastq_1,fastq_2,fasta
ERX5474932,ERR5766176,ILLUMINA,ERX5474932_ERR5766176_1.fastq.gz,ERX5474932_ERR5766176_2.fastq.gz,
ERX5474932,ERR5766176_B,ILLUMINA,ERX5474932_ERR5766176_B_1.fastq.gz,ERX5474932_ERR5766176_B_2.fastq.gz,
```

#### Prepare and run nf-core/taxprofiler command

Then we can set up our command for running nf-core/taxprofiler, using our samplesheet and nf-core/createtaxdb generated database `.csv`.

For the purpose of this tutorial, we will skip a lot of preprocessing steps and go straight to profiling.

```bash
nextflow run nf-core/taxprofiler \
  -profile docker \
  -c tutorial.conf \
  --input input.csv \
  --databases results/createtaxdb_downstream_samplesheets/databases-taxprofiler.csv \
  --outdir taxprofiler_results/ \
  --perform_shortread_qc \
  --run_centrifuge \
  --run_kraken2
```

Execute this command, and the pipeline should run!

### Clean Up

Once you have completed the tutorial, you can run the following command to delete all downloaded and output files.

```bash
rm -r createtaxdb-tutorial
```

:::warning
Don’t forget to change out of the directory above before trying to delete it!
:::

### Summary

In this tutorial we've shown you how you can generate input sheets for downstream pipelines.
In this case we told nf-core/createtaxdb with `--generate_downstream_samplesheets` and additional flags to create an analysis-ready database sheet that can be given to the nf-core/taxprofiler `--databases` flag.
