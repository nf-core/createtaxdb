// Database building (with specific auxiliary modules)

// Modules
include { CENTRIFUGE_BUILD                           } from '../../../modules/nf-core/centrifuge/build/main'
include { CENTRIFUGER_BUILD                          } from '../../../modules/nf-core/centrifuger/build/main'
include { DIAMOND_MAKEDB                             } from '../../../modules/nf-core/diamond/makedb/main'
include { GANON_BUILDCUSTOM                          } from '../../../modules/nf-core/ganon/buildcustom/main'
include { KAIJU_MKFMI                                } from '../../../modules/nf-core/kaiju/mkfmi/main'
include { KRAKENUNIQ_BUILD                           } from '../../../modules/nf-core/krakenuniq/build/main'
include { UNZIP                                      } from '../../../modules/nf-core/unzip/main'
include { MALT_BUILD                                 } from '../../../modules/nf-core/malt/build/main'
include { SYLPH_SKETCHGENOMES                        } from '../../../modules/nf-core/sylph/sketchgenomes/main'
include { METACACHE_BUILD                            } from '../../../modules/nf-core/metacache/build/main'

// Subworkflows
include { FASTA_BUILD_ADD_KRAKEN2_BRACKEN            } from '../../../subworkflows/nf-core/fasta_build_add_kraken2_bracken/main'
include { KMCP_CREATE                                } from '../../../subworkflows/local/kmcp_create/main'
include { SOURMASH_CREATE as SOURMASH_CREATE_DNA     } from '../../../subworkflows/local/sourmash_create/main'
include { SOURMASH_CREATE as SOURMASH_CREATE_PROTEIN } from '../../../subworkflows/local/sourmash_create/main'

workflow BUILDING {
    take:
    ch_singleref_for_dna // channel: [ val(meta), fasta ]
    ch_singleref_for_aa // channe: [ val(meta), fasta ]
    ch_ungrouped_dna_fastas // channel: [ [ val(meta), [ fasta ], [ val(meta), [ fasta ], [ val(meta), [ fasta ] ]
    ch_kaiju_aa // channe: [ val(meta), fasta ]
    ch_grouped_dna_fastas // channel: [ val(meta), [ fasta, fasta, fasta ] ]
    ch_grouped_aa_fastas // channel: [ val(meta), [ fasta, fasta, fasta ] ]
    file_taxonomy_namesdmp // file: taxonomy names file
    file_taxonomy_nodesdmp // file: taxonomy nodes file
    file_accession2taxid // file: accession2taxid file
    file_nucl2taxid // file: nucl2taxid file
    file_prot2taxid // file: prot2taxid file
    file_genomesizes // file: genome sizes file
    malt_build_mode // val: 'nucleotide' or 'protein'
    file_malt_mapdb // file: maltmap file

    main:
    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DATABASE BUILDING
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Module: Run CENTRIFUGE/BUILD

    if (params.build_centrifuge) {
        CENTRIFUGE_BUILD(ch_singleref_for_dna, file_nucl2taxid, file_taxonomy_nodesdmp, file_taxonomy_namesdmp, [])
        ch_versions = ch_versions.mix(CENTRIFUGE_BUILD.out.versions)
        ch_centrifuge_output = CENTRIFUGE_BUILD.out.cf
    }
    else {
        ch_centrifuge_output = channel.empty()
    }

    // Module: Run CENTRIFUGER/BUILD

    if (params.build_centrifuger) {
        CENTRIFUGER_BUILD(ch_singleref_for_dna, file_taxonomy_nodesdmp, file_taxonomy_namesdmp, file_nucl2taxid)
        ch_centrifuger_output = CENTRIFUGER_BUILD.out.db
    }
    else {
        ch_centrifuger_output = channel.empty()
    }

    // MODULE: Run DIAMOND/MAKEDB

    if (params.build_diamond) {
        DIAMOND_MAKEDB(ch_singleref_for_aa, file_prot2taxid, file_taxonomy_nodesdmp, file_taxonomy_namesdmp)
        ch_versions = ch_versions.mix(DIAMOND_MAKEDB.out.versions)
        ch_diamond_output = DIAMOND_MAKEDB.out.db
    }
    else {
        ch_diamond_output = channel.empty()
    }

    if (params.build_ganon) {

        ch_ganon_input_tsv = ch_ungrouped_dna_fastas
            .map { meta, fasta ->
                // I tried with .name() but it kept giving error of `Unknown method invocation `name` on XPath type... not sure why
                def fasta_name = fasta.toString().split('/').last()
                [fasta_name, meta.id, meta.taxid]
            }
            .map { fastas -> fastas.join("\t") }
            .collectFile(
                name: "ganon_fasta_input.tsv",
                newLine: true,
            )
            .map { files ->
                [[id: params.dbname], files]
            }

        // Nodes must come
        ch_ganon_tax_files = channel.fromPath(file_taxonomy_nodesdmp).combine(channel.fromPath(file_taxonomy_namesdmp))

        GANON_BUILDCUSTOM(ch_grouped_dna_fastas, ch_ganon_input_tsv.map { _meta, tsv -> tsv }, ch_ganon_tax_files, file_genomesizes)
        ch_versions = ch_versions.mix(GANON_BUILDCUSTOM.out.versions)
        ch_ganon_output = GANON_BUILDCUSTOM.out.db
    }
    else {
        ch_ganon_output = channel.empty()
    }

    // MODULE: Run KAIJU/MKFMI

    if (params.build_kaiju) {
        KAIJU_MKFMI(ch_kaiju_aa, file_taxonomy_nodesdmp, file_taxonomy_namesdmp, params.kaiju_keepintermediate)
        ch_kaiju_output = KAIJU_MKFMI.out.fmi
    }
    else {
        ch_kaiju_output = channel.empty()
    }

    // SUBWORKFLOW: Kraken2 and Bracken
    // Bracken requires intermediate files, if build_bracken=true then kraken2_keepintermediate=true, otherwise an error will be raised
    // Condition is inverted because subworkflow asks if you want to 'clean' (true) or not, but pipeline says to 'keep'
    if (params.build_kraken2 || params.build_bracken) {
        def k2_keepintermediates = params.kraken2_keepintermediate || params.build_bracken ? false : true
        FASTA_BUILD_ADD_KRAKEN2_BRACKEN(ch_singleref_for_dna, file_taxonomy_namesdmp, file_taxonomy_nodesdmp, file_accession2taxid, k2_keepintermediates, file_nucl2taxid, params.build_bracken)
        ch_kraken2_bracken_output = FASTA_BUILD_ADD_KRAKEN2_BRACKEN.out.db
    }
    else {
        ch_kraken2_bracken_output = channel.empty()
    }

    // SUBWORKFLOW: Run KRAKENUNIQ/BUILD
    if (params.build_krakenuniq) {

        ch_taxdmpfiles_for_krakenuniq = channel.of(file_taxonomy_namesdmp)
            .combine(channel.of(file_taxonomy_nodesdmp))
            .map { taxdmp_files -> [taxdmp_files] }

        channel.of(file_nucl2taxid)
        ch_input_for_krakenuniq = ch_grouped_dna_fastas
            .combine(ch_taxdmpfiles_for_krakenuniq)
            .map { meta, fastas, taxdump ->
                [meta, fastas, taxdump, file_nucl2taxid]
            }

        KRAKENUNIQ_BUILD(ch_input_for_krakenuniq, params.krakenuniq_keepintermediate)
        ch_krakenuniq_output = KRAKENUNIQ_BUILD.out.db
    }
    else {
        ch_krakenuniq_output = channel.empty()
    }

    // Module: Run MALT/BUILD

    if (params.build_malt) {

        // The map DB file comes zipped (for some reason) from MEGAN6 website
        if (file_malt_mapdb.extension == 'zip') {
            ch_malt_mapdb = UNZIP([[], file_malt_mapdb]).unzipped_archive.map { _meta, file -> [file] }
            ch_versions = ch_versions.mix(UNZIP.out.versions)
        }
        else {
            ch_malt_mapdb = file(file_malt_mapdb)
        }

        if (malt_build_mode == 'protein') {
            ch_input_for_malt = ch_grouped_aa_fastas.map { _meta, file -> file }
        }
        else {
            ch_input_for_malt = ch_grouped_dna_fastas.map { _meta, file -> file }
        }

        MALT_BUILD(ch_input_for_malt, [], ch_malt_mapdb, params.malt_mapdb_format)
        ch_versions = ch_versions.mix(MALT_BUILD.out.versions)
        ch_malt_output = MALT_BUILD.out.index
    }
    else {
        ch_malt_output = channel.empty()
    }


    // SUBWORKFLOW: Run KMCP_CREATE
    if (params.build_kmcp) {
        KMCP_CREATE(ch_ungrouped_dna_fastas, ch_grouped_dna_fastas, file_taxonomy_nodesdmp, file_taxonomy_namesdmp)
        ch_kmcp_output = KMCP_CREATE.out.db
    }
    else {
        ch_kmcp_output = channel.empty()
    }

    // SUBWORKFLOW: Run SOURMASH_CREATE_DNA
    if (params.build_sourmash_dna) {
        SOURMASH_CREATE_DNA(
            ch_grouped_dna_fastas,
            channel.fromList(parse_kmer_sizes(params.sourmash_build_dna_options)),
            params.sourmash_batch_size,
        )
        ch_sourmash_dna_output = SOURMASH_CREATE_DNA.out.db
    }
    else {
        ch_sourmash_dna_output = channel.empty()
    }

    // SUBWORKFLOW: Run SOURMASH_CREATE_PROTEIN
    if (params.build_sourmash_protein) {
        SOURMASH_CREATE_PROTEIN(
            ch_grouped_aa_fastas,
            channel.fromList(parse_kmer_sizes(params.sourmash_build_protein_options)),
            params.sourmash_batch_size,
        )
        ch_sourmash_aa_output = SOURMASH_CREATE_PROTEIN.out.db
    }
    else {
        ch_sourmash_aa_output = channel.empty()
    }

    // MODULE : Run SYLPH/SKETCHGENOMES
    if (params.build_sylph) {
        SYLPH_SKETCHGENOMES(ch_grouped_dna_fastas)
        ch_versions = ch_versions.mix(SYLPH_SKETCHGENOMES.out.versions)
        ch_sylph_output = SYLPH_SKETCHGENOMES.out.syldb
    }
    else {
        ch_sylph_output = channel.empty()
    }

    // MODULE : Run METACACHE/BUILD
    if (params.build_metacache) {
        METACACHE_BUILD(
            ch_grouped_dna_fastas,
            [file_taxonomy_namesdmp, file_taxonomy_nodesdmp],
            [file_accession2taxid],
        )
        // Current module emits the two file as separate elements of the same tuple, so we need to combine them here
        // to satisfy our later final output directory
        ch_metacache_output = METACACHE_BUILD.out.db.map { meta, dbmeta, dbcache -> [meta, [dbmeta, dbcache]] }
    }
    else {
        ch_metacache_output = channel.empty()
    }

    //
    // Aggregate all databases for downstream processes
    //
    ch_all_databases = channel.empty()
        .mix(
            ch_centrifuge_output.map { meta, db -> [meta + [tool: "centrifuge", type: 'dna'], db] },
            ch_diamond_output.map { meta, db -> [meta + [tool: "diamond", type: 'protein'], db] },
            ch_ganon_output.map { meta, db -> [meta + [tool: "ganon", type: 'dna'], db] },
            ch_kaiju_output.map { meta, db -> [meta + [tool: "kaiju", type: 'protein'], db] },
            ch_kraken2_bracken_output.map { meta, db -> [meta + [tool: params.build_bracken ? "bracken" : "kraken2", type: 'dna'], db] },
            ch_krakenuniq_output.map { meta, db -> [meta + [tool: "krakenuniq", type: 'dna'], db] },
            ch_malt_output.map { db -> [[id: params.dbname, tool: "malt", type: malt_build_mode == 'protein' ? 'protein' : 'dna'], db] },
            ch_kmcp_output.map { meta, db -> [meta + [tool: "kmcp", type: 'dna'], db] },
            ch_sourmash_dna_output.map { meta, db -> [meta + [tool: 'sourmash', type: 'dna'], db] },
            ch_sourmash_aa_output.map { meta, db -> [meta + [tool: 'sourmash', type: 'protein'], db] },
            ch_sylph_output.map { meta, db -> [meta + [tool: 'sylph', type: 'dna'], db] },
            ch_metacache_output.map { meta, db -> [meta + [tool: 'metacache', type: 'dna'], db] },
        )

    emit:
    versions               = ch_versions
    multiqc_files          = ch_multiqc_files
    centrifuge_output      = ch_centrifuge_output
    centrifuger_output     = ch_centrifuger_output
    diamond_output         = ch_diamond_output
    ganon_output           = ch_ganon_output
    kaiju_output           = ch_kaiju_output
    kraken2_bracken_output = ch_kraken2_bracken_output
    krakenuniq_output      = ch_krakenuniq_output
    malt_output            = ch_malt_output
    kmcp_output            = ch_kmcp_output
    sourmash_dna_output    = ch_sourmash_dna_output
    sourmash_aa_output     = ch_sourmash_aa_output
    sylph_output           = ch_sylph_output
    metacache_output       = ch_metacache_output
    all_databases          = ch_all_databases
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTION DEFINITIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/**
 * Parse k-mer sizes from a sourmash build options string.
 *
 * @param build_options The sourmash build options string.
 * @return A list of k-mer sizes as integers.
 */
def parse_kmer_sizes(build_options) {
    if ((build_options =~ /(-p|--param-string)/).size() != 1) {
        throw new IllegalArgumentException("Error parsing k-mer sizes from sourmash build options: ${build_options}. Please provide exactly one '-p' or '--param-string' argument.")
    }

    def matches = build_options =~ /k=(\d+)/
    return matches.collect { match -> match[1] as Integer }
}
