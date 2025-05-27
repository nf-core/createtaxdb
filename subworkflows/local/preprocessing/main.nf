include { FIND_UNPIGZ as UNPIGZ_DNA                     } from '../../../modules/nf-core/find/unpigz/main'
include { FIND_UNPIGZ as UNPIGZ_AA                      } from '../../../modules/nf-core/find/unpigz/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_DNA      } from '../../../modules/nf-core/find/concatenate/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_AA       } from '../../../modules/nf-core/find/concatenate/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_AA_KAIJU } from '../../../modules/nf-core/find/concatenate/main'
include { SEQKIT_BATCH_RENAME                           } from '../../../modules/local/seqkit/batch_rename/main'

workflow PREPROCESSING {
    take:
    ch_samplesheet  // channel: samplesheet read in from --input
    malt_build_mode // string: 'nucleotide' or 'protein'

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Initialise channels which may or may not get set depending on parameters
    ch_singleref_for_dna = Channel.empty()
    ch_singleref_for_aa = Channel.empty()
    ch_prepped_dna_fastas = Channel.empty()
    ch_prepped_aa_fastas = Channel.empty()
    ch_prepped_dna_fastas_ungrouped = Channel.empty()
    ch_prepped_aa_fastas_ungrouped = Channel.empty()
    ch_prepped_aa_fastas_kaiju = Channel.empty()

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DATA PREPARATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    // PREPARE: Prepare input for single file inputs modules
    if ([(params.build_malt && malt_build_mode == 'nucleotide'), params.build_centrifuge, params.build_kraken2, params.build_bracken, params.build_krakenuniq, params.build_ganon].any()) {

        // Pull just DNA sequences
        ch_dna_refs_for_singleref = ch_samplesheet
            .map { meta, fasta_dna, _fasta_aa -> [meta, fasta_dna] }
            .filter { _meta, fasta_dna ->
                fasta_dna
            }

        // Make channel to preserve meta for decompress/compression
        ch_dna_refs_for_rematching = ch_samplesheet
            .filter { _meta, fasta_dna, _fasta_aa ->
                fasta_dna
            }
            .map { meta, fasta_dna, _fasta_aa ->
                [
                    fasta_dna.getBaseName(fasta_dna.name.endsWith('.gz') ? 1 : 0),
                    meta,
                ]
            }


        // Separate files for zipping and unzipping
        ch_dna_for_unzipping = ch_dna_refs_for_singleref.branch { _meta, fasta ->
            zipped: fasta.extension == 'gz'
            unzipped: true
        }

        // Batch the zipped files for efficient unzipping of multiple files in a single process job
        ch_dna_batches_for_unzipping = ch_dna_for_unzipping.zipped
            .map { _meta, fasta -> fasta }
            .collate(params.unzip_batch_size, true)
            .map { batch -> [[id: params.dbname], batch] }

        // Run the batch unzipping
        UNPIGZ_DNA(ch_dna_batches_for_unzipping)
        ch_versions = ch_versions.mix(UNPIGZ_DNA.out.versions.first())

        // Mix back in the originally unzipped files
        ch_prepped_dna_batches = UNPIGZ_DNA.out.file_out.mix(ch_dna_for_unzipping.unzipped)

        // Unbatch the unzipped files for rematching with metadata
        ch_prepped_dna_fastas_gunzipped = ch_prepped_dna_batches
            .flatMap { _meta, batch -> batch }
            .map { fasta -> [fasta.getName(), fasta] }

        // Match metadata back to the prepped DNA fastas with an inner join
        ch_prepped_dna_fastas_ungrouped = ch_prepped_dna_fastas_gunzipped
            .join(ch_dna_refs_for_rematching, failOnMismatch: true, failOnDuplicate: true)
            .map { _fasta_name, fasta, meta -> [meta, fasta] }

        // Prepare for making the mega file
        ch_prepped_dna_fastas = ch_prepped_dna_fastas_ungrouped
            .map { _meta, fasta ->
                [[id: params.dbname], fasta]
            }
            .groupTuple()

        // Place in single mega file
        FIND_CONCATENATE_DNA(ch_prepped_dna_fastas)
        ch_versions = ch_versions.mix(FIND_CONCATENATE_DNA.out.versions)
        ch_singleref_for_dna = FIND_CONCATENATE_DNA.out.file_out
    }

    if ([(params.build_malt && malt_build_mode == 'protein'), params.build_kaiju, params.build_diamond].any()) {

        ch_aa_refs_for_singleref = ch_samplesheet
            .map { meta, _fasta_dna, fasta_aa -> [meta, fasta_aa] }
            .filter { _meta, fasta_aa ->
                fasta_aa
            }

        ch_aa_refs_for_rematching = ch_samplesheet
            .filter { _meta, _fasta_dna, fasta_aa ->
                fasta_aa
            }
            .map { meta, _fasta_dna, fasta_aa ->
                [
                    fasta_aa.getBaseName(fasta_aa.name.endsWith('.gz') ? 1 : 0),
                    meta,
                ]
            }

        ch_aa_for_unzipping = ch_aa_refs_for_singleref.branch { _meta, fasta ->
            zipped: fasta.extension == 'gz'
            unzipped: true
        }

        ch_aa_batches_for_unzipping = ch_aa_for_unzipping.zipped
            .map { _meta, aa_fasta -> aa_fasta }
            .collate(params.unzip_batch_size, true)
            .map { batch -> [[id: params.dbname], batch] }

        // Run the batch unzipping
        UNPIGZ_AA(ch_aa_batches_for_unzipping)
        ch_versions = ch_versions.mix(UNPIGZ_AA.out.versions.first())

        // Mix back in the originally unzipped files
        ch_prepped_aa_batches = UNPIGZ_AA.out.file_out.mix(ch_aa_for_unzipping.unzipped)

        // Unbatch the unzipped files for rematching with metadata
        ch_prepped_aa_fastas_gunzipped = ch_prepped_aa_batches
            .flatMap { _meta, batch -> batch }
            .map { fasta -> [fasta.getName(), fasta] }

        // Match metadata back to the prepped DNA fastas with an inner join
        ch_prepped_aa_fastas_ungrouped = ch_prepped_aa_fastas_gunzipped
            .join(ch_aa_refs_for_rematching, failOnMismatch: true, failOnDuplicate: true)
            .map { _fasta_name, fasta, meta -> [meta, fasta] }

        ch_aa_fastas_to_rename = ch_prepped_aa_fastas_ungrouped
            .map { meta, fasta -> [fasta, "${fasta.name}\t^.*\$\t${meta.taxid}\t${fasta.getBaseName(fasta.name.endsWith('.gz') ? 1 : 0)}"] }
            .collate(params.unzip_batch_size, true)
            .map { fasta_batch ->
                fasta_batch.transpose()
            }
            .multiMap { fasta_batch, replace_tsv_lines ->
                fasta: [[id: params.dbname], fasta_batch]
                replace_tsv: replace_tsv_lines
            }

        ch_prepped_aa_fastas = ch_prepped_aa_fastas_ungrouped
            .map { _meta, fasta -> [[id: params.dbname], fasta] }
            .groupTuple()

        ch_versions = ch_versions.mix(UNPIGZ_AA.out.versions.first())

        if ([(params.build_malt && malt_build_mode == 'protein'), params.build_diamond].any()) {
            FIND_CONCATENATE_AA(ch_prepped_aa_fastas)
            ch_singleref_for_aa = FIND_CONCATENATE_AA.out.file_out
            ch_versions = ch_versions.mix(FIND_CONCATENATE_AA.out.versions.first())
        }

        if ([params.build_kaiju].any()) {
            SEQKIT_BATCH_RENAME(ch_aa_fastas_to_rename.fasta, ch_aa_fastas_to_rename.replace_tsv)
            ch_versions = ch_versions.mix(SEQKIT_BATCH_RENAME.out.versions.first())

            FIND_CONCATENATE_AA_KAIJU(SEQKIT_BATCH_RENAME.out.fastx)
            ch_prepped_aa_fastas_kaiju = FIND_CONCATENATE_AA_KAIJU.out.file_out
            ch_versions = ch_versions.mix(FIND_CONCATENATE_AA_KAIJU.out.versions.first())
        }
    }

    emit:
    singleref_for_dna  = ch_singleref_for_dna
    singleref_for_aa   = ch_singleref_for_aa
    grouped_dna_fastas = ch_prepped_dna_fastas
    grouped_aa_fastas  = ch_prepped_aa_fastas
    ungrouped_dna      = ch_prepped_dna_fastas_ungrouped
    ungrouped_aa       = ch_prepped_aa_fastas_ungrouped
    kaiju_aa           = ch_prepped_aa_fastas_kaiju
    versions           = ch_versions
    multiqc_files      = ch_multiqc_files
}
