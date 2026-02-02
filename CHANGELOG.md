# nf-core/createtaxdb: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.1.0 - Gracious Goblin - [2026-02-04]

### `Added`

- [#117](https://github.com/nf-core/createtaxdb/pull/117) - Updated to nf-core/tools template 3.5.1 (by @jfy133)
- [#143](https://github/com/nf-core/createtaxdb/pull/143) - Documented how to resovle KrakenUniq unbound variable jellyfish issue (❤️ to @flass for suggesting, added by @jfy133)
- [#140](https://github/com/nf-core/createtaxdb/pull/140) - Added MetaCache database building support (❤️ to @ChillarAnand for suggestion, added by @alxndrdiaz and @jfy133)
- [#144](https://github.com/nf-core/createtaxdb/pull/144) - Added tutorial on how to convert an NCBI `assembly_summary.txt` file to input samplesheet (❤️ to @dialvarezs for improvements, by @jfy133)

### `Fixed`

### `Dependencies`

| Tool      | Old Version | New Version |
| --------- | ----------- | ----------- |
| nf-core   | 3.4.1       | 3.5.1       |
| MetaCache |             | 2.5.0       |

### `Deprecated`

## v2.0.0 - Charming Chaac - [2025-11-14]

### `Added`

- [#108](https://github.com/nf-core/createtaxdb/pull/108) - Document workaround for building databases from single FASTA files, e.g. from NCBI RefSeq (by @pcantalupo)
- [#111](https://github.com/nf-core/createtaxdb/pull/111) - Added sourmash reference building both for genomes and proteomes (by @Midnighter).
- [#117](https://github.com/nf-core/createtaxdb/pull/117) - Updated to nf-core/tools template 3.4.1 (by @jfy133)
- [#124](https://github.com/nf-core/createtaxdb/pull/124) - Added sylph reference building (by @jfy133 and @sofstam).

### `Fixed`

- [#110](https://github.com/nf-core/createtaxdb/pull/110) - Corrected the documented structures of the grouped output from the `PREPROCESSING` subworkflow
  (by @Midnighter).
- [#121](https://github.com/nf-core/createtaxdb/pull/121) - Fix Kraken2 build failing with local files due to symlink-in-symlink mounting error with containers (❤️ to @ellmagu for reporting, fix by @jfy133)
- [#122](https://github.com/nf-core/createtaxdb/pull/122) - Update DIAMOND to support more recent versions of NCBI taxonomy (by @jfy133)
- [#123](https://github.com/nf-core/createtaxdb/pull/123) - Fix a MALT build validation check incorrectly assigned to --build_krakenuniq (by @jfy133)
- [#133](https://github.com/nf-core/createtaxdb/pull/133) - Fix Kaiju compatible renamed FASTA files being always published even if --kaiju_keepintermediates false (by @jfy133)

### `Dependencies`

| Tool     | Old Version | New Version |
| -------- | ----------- | ----------- |
| sourmash |             | 4.9.4       |
| sylph    |             | 0.9.0       |
| kraken2  | 2.1.5       | 2.1.6       |
| tar      | 1.34        |             |
| nf-core  | 3.3.2       | 3.4.1       |
| DIAMOND  | 2.1.12      | 2.1.16      |
| MultiQC  | 1.31        | 1.32        |
| Nextflow | 24.04.2     | 25.04.2     |

### `Deprecated`

- [#118](https://github.com/nf-core/createtaxdb/pull/118) - Deprecated automated building of `tar.gz` archives of all databases (by @jfy133)
- [#126](https://github.com/nf-core/createtaxdb/pull/126) - Remove guidance about needed double and single quotes when giving to `--<tool>_build_options` as actually not necessary (by @jfy133)

## v1.0 - Helpful Hydra - [2025-06-19]

### `Added`

Initial release of nf-core/createtaxdb, created with the [nf-core](https://nf-co.re/) template.

Adds database building support for the following tools:

- (Primarily) nucleotide based
  - Bracken (added by @alxndrdiaz)
  - Centrifuge (added by @jfy133)
  - ganon (added by @jfy133)
  - KMCP (added by @alxndrdiaz)
  - KrakenUniq (added by @jfy133)
  - Kraken2 (added by @alxndrdiaz)
  - MALT (added by @jfy133 and @LilyAnderssonLee)
- (Primarily) protein based
  - DIAMOND (added by @jfy133)
  - Kaiju (added by @jfy133)

Additional optimisation when running with very large number of genomes by @BioWilko.

| Tool       | Old Version | New Version |
| ---------- | ----------- | ----------- |
| Bracken    |             | 3.1         |
| Centrifuge |             | 1.0.4.2     |
| DIAMOND    |             | 2.1.12      |
| find       |             | 4.6.0       |
| ganon      |             | 2.1.0       |
| kaiju      |             | 1.10.0      |
| KMCP       |             | 0.9.4       |
| Kraken2    |             | 2.1.5       |
| KrakenUniq |             | 1.0.4       |
| MALT       |             | 0.6.2       |
| pigz       |             | 2.8         |
| seqkit     |             | 2.9.0       |
| tar        |             | 1.34        |
| MultiQC    |             | 1.29        |
| p7zip      |             | 16.02       |

### `Fixed`

### `Dependencies`

### `Deprecated`
