# Frequently asked questions and troubleshooting

## Recommended auxiliary files

Some tools may require or recommend additional files to the reference sequence files - such as taxonomy files - to execute.

We provide a list of required or recommended files, and which pipeline parameters to give them to here:

- bracken
  - taxonomy name dump file (`--namesdmp`)
  - taxonomy nodes dump file (`--nodesdmp`)
  - (nucleotide) accession2taxid file (`--accession2taxid`)
- centrifuge
  - taxonomy name dump file (`--namesdmp`)
  - taxonomy nodes dump file (`--nodesdmp`)
  - nucl2taxid file (`--nucl2taxid`)
- diamond
  - taxonomy name dump file (`--namesdmp`)
  - taxonomy nodes dump file (`--nodesdmp`)
  - prot2taxid file (`--prot2taxid`)
- ganon
  - taxonomy name dump file (`--namesdmp`)
  - taxonomy nodes dump file (`--nodesdmp`)
- kaiju (no additional files required)
- kraken2
  - taxonomy name dump file (`--namesdmp`)
  - taxonomy nodes dump file (`--nodesdmp`)
  - (nucleotide) accession2taxid file (`--accession2taxid`)
  - (optional) custom seqid2taxid file (`--nucl2taxid`)
- krakenuniq
  - taxonomy name dump file (`--namesdmp`)
  - taxonomy nodes dump file (`--nodesdmp`)
  - (nucleotide) accession2taxid file (`--accession2taxid`)
- malt
  - a MEGAN 'mapDB' mapping file (`--malt_mapdb`)

## What should an X auxiliary file look like?

Some database building tools require additional files to be supplied to the pipeline.
These are typically taxonomy files, and each are formatted in different ways.

### names dump

This is a NCBI taxdump-style taxonomy file, that associates taxon IDs with human-readable names.

From NCBI, these would correspond to `taxdmp.tar.gz` from the [NCBI Taxonomy FTP server](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/).
Always refer to the [NCBI taxdump README](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump_readme.txt) for the most up-to-date information.

It is formatted as a tab-pipe (`\t|\t`)-separated file with four columns but no header row.

| Column | Column Name\* | Description                                                              |
| ------ | ------------- | ------------------------------------------------------------------------ |
| 1      | tax_id        | The taxon ID                                                             |
| 2      | name_txt      | The human-readable name of the taxon                                     |
| 3      | unique name   | The unique variant of the name if not unique                             |
| 4      | name class    | The type or category of the name (e.g. scientific, common name, synonym) |

\* Column names as defined in the taxdump README, however not used in the file itself

Example:

```txt
1	|	all	|		|	synonym	|
1	|	root	|		|	scientific name	|
2	|	Bacteria	|	Bacteria <bacteria>	|	scientific name	|
2	|	bacteria	|		|	blast name	|
2	|	eubacteria	|		|	genbank common name	|
2	|	Monera	|	Monera <bacteria>	|	in-part	|
2	|	Procaryotae	|	Procaryotae <bacteria>	|	in-part	|
2	|	Prokaryotae	|	Prokaryotae <bacteria>	|	in-part	|
2	|	Prokaryota	|	Prokaryota <bacteria>	|	in-part	|
2	|	prokaryote	|	prokaryote <bacteria>	|	in-part	|
2	|	prokaryotes	|	prokaryotes <bacteria>	|	in-part	|
712	|	Pasteurellaceae Pohl 1981	|		|	authority	|
712	|	Pasteurellaceae	|		|	scientific name	|
724	|	Haemophilus	|		|	scientific name	|
724	|	Haemophilus Winslow et al. 1917	|		|	authority	|
```

### nodes dump

This is a NCBI taxdump-style taxonomy file, that associates taxon IDs their taxonomic parent within the taxonomic hierarchy.

From NCBI, these would correspond to `taxdmp.tar.gz` from the [NCBI Taxonomy FTP server](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/).
Always refer to the [NCBI taxdump README](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump_readme.txt) for the most up-to-date information.

It is formatted as a tab-pipe (`\t|\t`)-separated file with fourteen columns but no header row.

| Column | Column Name\*                 | Description                                                                                                                    |
| ------ | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 1      | tax_id                        | The taxon ID                                                                                                                   |
| 2      | parent tax_id                 | The taxon ID of the parent taxon                                                                                               |
| 3      | rank                          | The NCBI taxonomic rank of the taxon                                                                                           |
| 4      | embl code                     | The EMBL code for the taxon                                                                                                    |
| 5      | division id                   | The NCBI division ID for the taxon (referring to `diversion.dmp` NCBI taxdump file not used in nf-core/createtaxdb)            |
| 6      | inherited div flag            | 1 (true) or 0 flag if taxon entry inherits division ID from taxonomic parent                                                   |
| 7      | genetic code id               | The genetic code ID for the taxon (referring to `gencode.dmp` NCBI taxdump file not used in nf-core/createtaxdb)               |
| 8      | inherited gc flag             | 1 (true) or 0 flag if taxon entry inherits genetic code ID from taxonomic parent                                               |
| 9      | mitochondrial genetic code    | The mitochondrial genetic code ID for the taxon (referring to `gencode.dmp` NCBI taxdump file not used in nf-core/createtaxdb) |
| 10     | inherited mgc flag            | 1 (true) or 0 flag if taxonomic entry inherits mitocondrial gencode from parent taxon                                          |
| 11     | genbank hidden flag           | 1 (true) or 0 flag indicating if name is suppressed in NCBI GenBank database                                                   |
| 13     | hidden subtree root flag node | 1 (true) or 0 flag indicating if there is any sequence data                                                                    |
| 14     | comments                      | Comments about the taxon                                                                                                       |

\* Column names as defined in the taxdump README, however not used in the file itself

Example:

```txt
1	|	1	|	no rank	|		|	8	|	0	|	1	|	0	|	0	|	0	|	0	|	0	|		|
2	|	131567	|	superkingdom	|		|	0	|	0	|	11	|	0	|	0	|	0	|	0	|	0	|		|
712	|	135625	|	family	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
724	|	712	|	genus	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
727	|	724	|	species	|	HI	|	0	|	1	|	11	|	1	|	0	|	1	|	1	|	0	|	code compliant; specified	|
815	|	171549	|	family	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
816	|	815	|	genus	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
817	|	816	|	species	|	BF	|	0	|	1	|	11	|	1	|	0	|	1	|	1	|	0	|	code compliant; specified	|
976	|	68336	|	phylum	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|		|
1224	|	2	|	phylum	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|		|
1236	|	1224	|	class	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
1239	|	1783272	|	phylum	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|		|
1300	|	186826	|	family	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
1301	|	1300	|	genus	|		|	0	|	1	|	11	|	1	|	0	|	1	|	0	|	0	|	code compliant	|
1311	|	1301	|	species	|	SA	|	0	|	1	|	11	|	1	|	0	|	1	|	1	|	0	|	code compliant; specified	|
```

### accession2taxid

An accession2taxid file is a file that maps database sequence accession IDs (e.g. NCBI GenBank) to their corresponding taxon IDs.

From NCBI, these would correspond to `nucl_gb.accession2taxid.gz` and `prot.accession2taxid.gz` from the [NCBI taxonomy FTP server](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/).

It is formatted as a four column tab-separated file **with** a header row.

| Column | Column Name      | Description                                                                                                                                                                                                     |
| ------ | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1      | accession        | The accession ID of the sequence without a version - typically embedded as first part of a FASTA header entry (e.g. for `>NC_012920 Homo sapiens mitochondrion, complete genome)` the accession is `NC_012829`) |
| 2      | accesion.version | The full accession version of the accession with the version suffix (e.g. `.1`)                                                                                                                                 |
| 3      | taxid            | The taxon ID corresponding to the names/nodes.dmp                                                                                                                                                               |
| 4      | gi               | The old-style ([now deprecated](https://ncbiinsights.ncbi.nlm.nih.gov/2016/12/06/converting-gi-numbers-to-accession-version/)) NCBI GenInfo Identifier                                                          |

Example:

```tsv title=nucl_db.accession2taxid
accession	accession.version	taxid	gi
NC_018507	CP003708.1	91844	401871806
NZ_CP019811	CP019811.1	1311	1328913993
NZ_CP069563	CP069563.1	817	1986148684
NZ_CP069564	CP069564.1	817	1986152744
NC_012920	J01415.2	9606	113200490
NZ_LS483480	LS483480.1	727	1403648431
MT192765	MT192765.1	694009	1821109001
```

It's important to note that you can have multiple accession numbers within a FASTA file (i.e., one per sequence in the file), therefore accession2taxid mapping files should ensure they reference _all_ accession numbers that are present in the FASTA file.

The accession column should not include the accession version in the first column (i.e. `1`)

### nucl2taxid

An accession2taxid file is a file that maps database sequence accession IDs (e.g. NCBI GenBank) to their corresponding taxon IDs.

It is a simpler version of the accession2taxid file, and is formatted as a two column tab-separated file **without** a header row.

| Column | Column Name | Description                                                                                                                                                                                                               |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1      | accession   | The nucleotide accession ID with version of the sequence - typically embedded as first part of a FASTA header entry (e.g. for `>NC_012920.1 Homo sapiens mitochondrion, complete genome)` the accession is `NC_012829.1`) |
| 2      | taxon id    | The corresponding taxonomy ID of the sequence                                                                                                                                                                             |

Example:

```tsv title="nucl2tax.map"
NC_012920.1	9606
MT192765.1	694009
NZ_CP069563.1	817
NC_018507.1	91844
NZ_CP019811	1311
NZ_LS483480.1	727

```

### prot2taxid

An accession2taxid file is a file that maps database sequence accession IDs (e.g. NCBI GenBank) to their corresponding taxon IDs.

It is a simpler version of the accession2taxid file, and is formatted as a two column tab-separated file **with** a header row.

| Column | Column Name       | Description                                                                                                                                                                                                            |
| ------ | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1      | accession.version | The protein accession ID with version of the sequence - typically embedded as first part of a FASTA header entry (e.g. for `>NC_012920.1 Homo sapiens mitochondrion, complete genome)` the accession is `NC_012829.1`) |
| 2      | taxid             | The corresponding taxonomy ID of the sequence                                                                                                                                                                          |

Example:

```tsv title="nucl2tax.map"
accession.version	taxid
QIK50426.1	694009
QIK50427.1	694009
QIK50428.1	694009
QIK50429.1	694009
QIK50430.1	694009
QIK50431.1	694009
QIK50432.1	694009
QIK50433.1	694009
QIK50434.1	694009
QIK50435.1	694009
QIK50436.1	694009
WP_000002661.1	1311
WP_000002812.1	1311
WP_000003859.1	1311
```

### malt mapDB

A custom taxonomy database file from the [MEGAN6 toolkit](https://software-ab.cs.uni-tuebingen.de/download/megan/welcome.html) ending with `.db`.

This file must be unzipped before use, and is an SQLlite database consisting of two tables

- `info`
  - Three column table: `id`. `info_string`, `size`
  - Two rows: `general`, `Taxonomy`
  - The `info_string` of `general` has a string of Created <YYYY>-<MM>-<DD> <HH>:<MM>:<SS>, and a size of the number of taxonomic entries in the database
  - The `info_string` of `Taxonomy` has a string of `Source: nucl_gb.accession2taxid.gz` and a size of taxonomic entries in the database
- `mappings`
  - A two column table: `Accession`, `Taxonomy`
  - The `Accession` column contains the accession ID of the sequence with version (e.g. `NC_012920.1`)

## I want to supply a custom seqid2taxid file to Kraken2

While not officially supported by Kraken2, you can speed up the Kraken2 build process by providing the pipeline a premade `seqid2taxid.map` file.

This file should be a tab-separated file with two columns:

- the sequence ID as represented by the first part of each `>` entry of a FASTA file
- the taxon ID

To supply this to the pipeline, you can give this to the `--nucl2taxid` parameter, as the Kraken2 `seqid2taxid.map` file is the same as Centrifuge's `--conversion-table` file.
