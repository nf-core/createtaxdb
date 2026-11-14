/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                          } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                 } from 'plugin/nf-schema'
include { paramsSummaryMultiqc             } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML           } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText           } from '../subworkflows/local/utils_nfcore_createtaxdb_pipeline'


// Preprocessing
include { PREPROCESSING                    } from '../subworkflows/local/preprocessing/main'

// Building
include { BUILDING                         } from '../subworkflows/local/building/main'

// Post-processing
include { GENERATE_DOWNSTREAM_SAMPLESHEETS } from '../subworkflows/local/generate_downstream_samplesheets/main.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CREATETAXDB {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir
    file_taxonomy_namesdmp // file: taxonomy names file
    file_taxonomy_nodesdmp // file: taxonomy nodes file
    file_accession2taxid // file: accession2taxid file
    file_nucl2taxid // file: nucl2taxid file
    file_prot2taxid // file: prot2taxid file
    file_genomesizes // file: genome sizes file
    file_malt_mapdb // file: maltmap file

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    def malt_build_mode = null
    if (params.build_malt) {
        malt_build_mode = params.malt_build_options.contains('--sequenceType Protein') ? 'protein' : 'nucleotide'
    }

    PREPROCESSING(ch_samplesheet, malt_build_mode)

    ch_versions = ch_versions.mix(PREPROCESSING.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(PREPROCESSING.out.multiqc_files)


    BUILDING(
        PREPROCESSING.out.singleref_for_dna,
        PREPROCESSING.out.singleref_for_aa,
        PREPROCESSING.out.ungrouped_dna_fastas,
        PREPROCESSING.out.kaiju_aa,
        PREPROCESSING.out.grouped_dna_fastas,
        PREPROCESSING.out.grouped_aa_fastas,
        file_taxonomy_namesdmp,
        file_taxonomy_nodesdmp,
        file_accession2taxid,
        file_nucl2taxid,
        file_prot2taxid,
        file_genomesizes,
        malt_build_mode,
        file_malt_mapdb,
    )
    ch_versions = ch_versions.mix(BUILDING.out.versions)


    //
    // Samplesheet generation
    //
    if (params.generate_downstream_samplesheets) {
        ch_databases_for_samplesheets = BUILDING.out.all_databases
        GENERATE_DOWNSTREAM_SAMPLESHEETS(ch_databases_for_samplesheets)
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_' + 'createtaxdb_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'createtaxdb'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    versions                 = ch_versions // channel: [ path(versions.yml) ]
    multiqc_report           = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    centrifuge_database      = BUILDING.out.centrifuge_output
    centrifuger_database     = BUILDING.out.centrifuger_output
    diamond_database         = BUILDING.out.diamond_output
    ganon_database           = BUILDING.out.ganon_output
    kaiju_database           = BUILDING.out.kaiju_output
    kraken2_bracken_database = BUILDING.out.kraken2_bracken_output
    krakenuniq_database      = BUILDING.out.krakenuniq_output
    malt_database            = BUILDING.out.malt_output
    kmcp_database            = BUILDING.out.kmcp_output
    sourmash_dna_database    = BUILDING.out.sourmash_dna_output
    sourmash_aa_database     = BUILDING.out.sourmash_aa_output
    sylph_database           = BUILDING.out.sylph_output
    metacache_database       = BUILDING.out.metacache_output
    all_databases            = BUILDING.out.all_databases
}
