# nf-core/createtaxdb: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.0dev - [date]

### `Added`

- [#108](https://github.com/nf-core/createtaxdb/pull/108) - Document workaround for building databases from single FASTA files, e.g. from NCBI RefSeq (by @pcantalupo)

### `Fixed`

### `Dependencies`

### `Deprecated`

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
