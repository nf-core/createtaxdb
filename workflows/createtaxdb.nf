/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                                    } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                           } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                       } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                     } from '../subworkflows/local/utils_nfcore_createtaxdb_pipeline'


// Preprocessing
include { PREPROCESSING                              } from '../subworkflows/local/preprocessing/main'

// Database building (with specific auxiliary modules)
include { CENTRIFUGE_BUILD                           } from '../modules/nf-core/centrifuge/build/main'
include { DIAMOND_MAKEDB                             } from '../modules/nf-core/diamond/makedb/main'
include { GANON_BUILDCUSTOM                          } from '../modules/nf-core/ganon/buildcustom/main'
include { KAIJU_MKFMI                                } from '../modules/nf-core/kaiju/mkfmi/main'
include { KRAKENUNIQ_BUILD                           } from '../modules/nf-core/krakenuniq/build/main'
include { UNZIP                                      } from '../modules/nf-core/unzip/main'
include { MALT_BUILD                                 } from '../modules/nf-core/malt/build/main'

include { FASTA_BUILD_ADD_KRAKEN2_BRACKEN            } from '../subworkflows/nf-core/fasta_build_add_kraken2_bracken/main'
include { GENERATE_DOWNSTREAM_SAMPLESHEETS           } from '../subworkflows/local/generate_downstream_samplesheets/main.nf'
include { KMCP_CREATE                                } from '../subworkflows/local/kmcp_create/main.nf'
include { SOURMASH_CREATE as SOURMASH_CREATE_DNA     } from '../subworkflows/local/sourmash_create/main.nf'
include { SOURMASH_CREATE as SOURMASH_CREATE_PROTEIN } from '../subworkflows/local/sourmash_create/main.nf'

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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CREATETAXDB {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    file_taxonomy_namesdmp // file: taxonomy names file
    file_taxonomy_nodesdmp // file: taxonomy nodes file
    file_accession2taxid // file: accession2taxid file
    file_nucl2taxid // file: nucl2taxid file
    file_prot2taxid // file: prot2taxid file
    file_genomesizes // file: genome sizes file
    file_malt_mapdb // file: maltmap file

    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    def malt_build_mode = null
    if (params.build_malt) {
        malt_build_mode = params.malt_build_options.contains('--sequenceType Protein') ? 'protein' : 'nucleotide'
    }

    PREPROCESSING(ch_samplesheet, malt_build_mode)

    ch_versions = ch_versions.mix(PREPROCESSING.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(PREPROCESSING.out.multiqc_files)


    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DATABASE BUILDING
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Module: Run CENTRIFUGE/BUILD

    if (params.build_centrifuge) {
        CENTRIFUGE_BUILD(PREPROCESSING.out.singleref_for_dna, file_nucl2taxid, file_taxonomy_nodesdmp, file_taxonomy_namesdmp, [])
        ch_versions = ch_versions.mix(CENTRIFUGE_BUILD.out.versions.first())
        ch_centrifuge_output = CENTRIFUGE_BUILD.out.cf
    }
    else {
        ch_centrifuge_output = channel.empty()
    }

    // MODULE: Run DIAMOND/MAKEDB

    if (params.build_diamond) {
        DIAMOND_MAKEDB(PREPROCESSING.out.singleref_for_aa, file_prot2taxid, file_taxonomy_nodesdmp, file_taxonomy_namesdmp)
        ch_versions = ch_versions.mix(DIAMOND_MAKEDB.out.versions.first())
        ch_diamond_output = DIAMOND_MAKEDB.out.db
    }
    else {
        ch_diamond_output = channel.empty()
    }

    if (params.build_ganon) {

        ch_ganon_input_tsv = PREPROCESSING.out.ungrouped_dna
            .map { meta, fasta ->
                // I tried with .name() but it kept giving error of `Unknown method invocation `name` on XPath type... not sure why
                def fasta_name = fasta.toString().split('/').last()
                [fasta_name, meta.id, meta.taxid]
            }
            .map { it.join("\t") }
            .collectFile(
                name: "ganon_fasta_input.tsv",
                newLine: true,
            )
            .map {
                [[id: params.dbname], it]
            }

        // Nodes must come first
        ch_ganon_tax_files = channel.fromPath(file_taxonomy_nodesdmp).combine(channel.fromPath(file_taxonomy_namesdmp))

        GANON_BUILDCUSTOM(PREPROCESSING.out.grouped_dna_fastas, ch_ganon_input_tsv.map { _meta, tsv -> tsv }, ch_ganon_tax_files, file_genomesizes)
        ch_versions = ch_versions.mix(GANON_BUILDCUSTOM.out.versions.first())
        ch_ganon_output = GANON_BUILDCUSTOM.out.db
    }
    else {
        ch_ganon_output = channel.empty()
    }

    // MODULE: Run KAIJU/MKFMI

    if (params.build_kaiju) {
        KAIJU_MKFMI(PREPROCESSING.out.kaiju_aa, params.kaiju_keepintermediate)
        ch_versions = ch_versions.mix(KAIJU_MKFMI.out.versions.first())
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
        FASTA_BUILD_ADD_KRAKEN2_BRACKEN(PREPROCESSING.out.singleref_for_dna, file_taxonomy_namesdmp, file_taxonomy_nodesdmp, file_accession2taxid, k2_keepintermediates, file_nucl2taxid, params.build_bracken)
        ch_versions = ch_versions.mix(FASTA_BUILD_ADD_KRAKEN2_BRACKEN.out.versions)
        ch_kraken2_bracken_output = FASTA_BUILD_ADD_KRAKEN2_BRACKEN.out.db
    }
    else {
        ch_kraken2_bracken_output = channel.empty()
    }

    // SUBWORKFLOW: Run KRAKENUNIQ/BUILD
    if (params.build_krakenuniq) {

        ch_taxdmpfiles_for_krakenuniq = Channel
            .of(file_taxonomy_namesdmp)
            .combine(channel.of(file_taxonomy_nodesdmp))
            .map { [it] }

        channel.of(file_nucl2taxid)
        ch_input_for_krakenuniq = PREPROCESSING.out.grouped_dna_fastas.combine(ch_taxdmpfiles_for_krakenuniq).map { meta, fastas, taxdump -> [meta, fastas, taxdump, file_nucl2taxid] }

        KRAKENUNIQ_BUILD(ch_input_for_krakenuniq, params.krakenuniq_keepintermediate)
        ch_versions = ch_versions.mix(KRAKENUNIQ_BUILD.out.versions.first())
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
        }
        else {
            ch_malt_mapdb = file(file_malt_mapdb)
        }

        if (malt_build_mode == 'protein') {
            ch_input_for_malt = PREPROCESSING.out.grouped_aa_fastas.map { _meta, file -> file }
        }
        else {
            ch_input_for_malt = PREPROCESSING.out.grouped_dna_fastas.map { _meta, file -> file }
        }

        MALT_BUILD(ch_input_for_malt, [], ch_malt_mapdb, params.malt_mapdb_format)
        ch_versions = ch_versions.mix(MALT_BUILD.out.versions.first())
        ch_malt_output = MALT_BUILD.out.index
    }
    else {
        ch_malt_output = channel.empty()
    }


    // SUBWORKFLOW: Run KMCP_CREATE
    if (params.build_kmcp) {
        KMCP_CREATE(PREPROCESSING.out.singleref_for_dna)
        ch_kmcp_output = KMCP_CREATE.out.db
        ch_versions = ch_versions.mix(KMCP_CREATE.out.versions.first())
    }
    else {
        ch_kmcp_output = channel.empty()
    }

    // SUBWORKFLOW: Run SOURMASH_CREATE_DNA
    if (params.build_sourmash_dna) {
        SOURMASH_CREATE_DNA(
            PREPROCESSING.out.grouped_dna_fastas,
            channel.fromList(parse_kmer_sizes(params.sourmash_build_dna_options)),
            params.sourmash_batch_size,
        )

        ch_versions = ch_versions.mix(SOURMASH_CREATE_DNA.out.versions.first())

        ch_sourmash_dna_output = SOURMASH_CREATE_DNA.out.db
    }
    else {
        ch_sourmash_dna_output = channel.empty()
    }

    // SUBWORKFLOW: Run SOURMASH_CREATE_PROTEIN
    if (params.build_sourmash_protein) {
        SOURMASH_CREATE_PROTEIN(
            PREPROCESSING.out.grouped_aa_fastas,
            channel.fromList(parse_kmer_sizes(params.sourmash_build_protein_options)),
            params.sourmash_batch_size,
        )

        ch_versions = ch_versions.mix(SOURMASH_CREATE_PROTEIN.out.versions.first())

        ch_sourmash_protein_output = SOURMASH_CREATE_PROTEIN.out.db
    }
    else {
        ch_sourmash_protein_output = channel.empty()
    }

    //
    // Aggregate all databases for downstream processes
    //
    ch_all_databases = Channel
        .empty()
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
            ch_sourmash_protein_output.map { meta, db -> [meta + [tool: 'sourmash', type: 'protein'], db] },
        )

    //
    // Samplesheet generation
    //
    if (params.generate_downstream_samplesheets) {
        ch_databases_for_samplesheets = ch_all_databases
        GENERATE_DOWNSTREAM_SAMPLESHEETS(ch_databases_for_samplesheets)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_' + 'createtaxdb_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config = channel.fromPath(
        "${projectDir}/assets/multiqc_config.yml",
        checkIfExists: true
    )
    ch_multiqc_custom_config = params.multiqc_config
        ? channel.fromPath(params.multiqc_config, checkIfExists: true)
        : channel.empty()
    ch_multiqc_logo = params.multiqc_logo
        ? channel.fromPath(params.multiqc_logo, checkIfExists: true)
        : channel.empty()

    summary_params = paramsSummaryMap(
        workflow,
        parameters_schema: "nextflow_schema.json"
    )
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
    )
    ch_multiqc_custom_methods_description = params.multiqc_methods_description
        ? file(params.multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description)
    )

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true,
        )
    )

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    emit:
    versions                 = ch_versions // channel: [ path(versions.yml) ]
    multiqc_report           = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    centrifuge_database      = ch_centrifuge_output
    diamond_database         = ch_diamond_output
    ganon_database           = ch_ganon_output
    kaiju_database           = ch_kaiju_output
    kraken2_bracken_database = ch_kraken2_bracken_output
    krakenuniq_database      = ch_krakenuniq_output
    malt_database            = ch_malt_output
    kmcp_databae             = ch_kmcp_output
    sourmash_dna_database    = ch_sourmash_dna_output
    sourmash_aa_database     = ch_sourmash_protein_output
}
