/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet  } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowCreatetaxdb.initialise(params, log)

// Validate input files parameters (from Sarek)
def checkPathParamList = [
    params.prot2taxid,
    params.nucl2taxid,
    params.nodesdmp,
    params.namesdmp,
    params.malt_mapdb,
]

for (param in checkPathParamList) if (param) file(param, checkIfExists: true)

// Validate parameter combinations
if ( params.build_diamond && [!params.prot2taxid, !params.nodesdmp, !params.namesdmp,].any() ) { error('[nf-core/createtaxdb] Supplied --build_diamond, but missing at least one of: --prot2taxid, --nodesdmp, or --namesdmp (all are mandatory for DIAMOND)') }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

include { CAT_CAT as CAT_CAT_DNA             } from '../modules/nf-core/cat/cat/main'
include { CAT_CAT as CAT_CAT_AA              } from '../modules/nf-core/cat/cat/main'
include { CENTRIFUGE_BUILD                   } from '../modules/nf-core/centrifuge/build/main'
include { KAIJU_MKFMI                        } from '../modules/nf-core/kaiju/mkfmi/main'
include { DIAMOND_MAKEDB                     } from '../modules/nf-core/diamond/makedb/main'
include { MALT_BUILD                         } from '../modules/nf-core/malt/build/main'
include { PIGZ_COMPRESS as PIGZ_COMPRESS_DNA } from '../modules/nf-core/pigz/compress/main'
include { PIGZ_COMPRESS as PIGZ_COMPRESS_AA  } from '../modules/nf-core/pigz/compress/main'
include { UNZIP                              } from '../modules/nf-core/unzip/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CREATETAXDB {

    ch_versions = Channel.empty()

    //
    // INPUT: Read in samplesheet, validate and stage input files
    //
    ch_input = Channel.fromSamplesheet("input")

    // PREPARE: Prepare input for single file inputs modules

    if ( [params.build_malt, params.build_centrifuge].any() ) {  // Pull just DNA sequences

        ch_dna_refs_for_singleref = ch_input
                                        .map{meta, fasta_dna, fasta_aa  -> [[id: params.dbname], fasta_dna]}
                                        .filter{meta, fasta_dna ->
                                            fasta_dna
                                        }

        ch_dna_for_zipping = ch_dna_refs_for_singleref
                                .branch {
                                    meta, fasta ->
                                        zipped: fasta.extension == 'gz'
                                        unzipped: true
                                }

        PIGZ_COMPRESS_DNA ( ch_dna_for_zipping.unzipped )

        ch_prepped_dna_fastas = PIGZ_COMPRESS_DNA.out.archive.mix(ch_dna_for_zipping.zipped).groupTuple()

        // Place in single file
        ch_singleref_for_dna = CAT_CAT_DNA ( ch_prepped_dna_fastas )
        ch_versions = ch_versions.mix(CAT_CAT_DNA.out.versions.first())
    }

    // TODO: Possibly need to have a modification step to get header correct to actually run with kaiju...
    // TEST first!
    // docs: https://github.com/bioinformatics-centre/kaiju#custom-database
    // docs: https://github.com/nf-core/test-datasets/tree/taxprofiler#kaiju
    // idea: try just appending `_<tax_id_from_meta>` to end of each sequence header using a local sed module... it might be sufficient
    if ( [params.build_kaiju, params.build_diamond].any() ) {

        ch_aa_refs_for_singleref = ch_input
                                        .map{meta, fasta_dna, fasta_aa  -> [[id: params.dbname], fasta_aa]}
                                        .filter{meta, fasta_aa ->
                                            fasta_aa
                                        }

        ch_aa_for_zipping = ch_aa_refs_for_singleref
                                .branch {
                                    meta, fasta ->
                                        zipped: fasta.extension == 'gz'
                                        unzipped: true
                                }

        PIGZ_COMPRESS_AA ( ch_aa_for_zipping.unzipped )

        ch_prepped_aa_fastas = PIGZ_COMPRESS_AA.out.archive.mix(ch_aa_for_zipping.zipped).groupTuple()

        ch_singleref_for_aa = CAT_CAT_AA ( ch_prepped_aa_fastas )
        ch_versions = ch_versions.mix(CAT_CAT_AA.out.versions.first())
    }

    //
    // MODULE: Run DIAMOND/MAKEDB
    //

    if ( params.build_diamond  ) {
        DIAMOND_MAKEDB ( CAT_CAT_AA.out.file_out, params.prot2taxid, params.nodesdmp, params.namesdmp )
        ch_versions = ch_versions.mix(DIAMOND_MAKEDB.out.versions.first())
        ch_diamond_output = DIAMOND_MAKEDB.out.db
    } else {
        ch_diamond_output = Channel.empty()
    }

    //
    // MODULE: Run KAIJU/MKFMI
    //

    if ( params.build_kaiju ) {
        KAIJU_MKFMI ( CAT_CAT_AA.out.file_out )
        ch_versions = ch_versions.mix(KAIJU_MKFMI.out.versions.first())
        ch_kaiju_output = KAIJU_MKFMI.out.fmi
    } else {
        ch_kaiju_output = Channel.empty()
    }

    // Module: Run CENTRIFUGE/BUILD

    if ( params.build_centrifuge ) {
        CENTRIFUGE_BUILD ( CAT_CAT_DNA.out.file_out, params.nucl2taxid, params.nodesdmp, params.namesdmp, [] )
        ch_versions = ch_versions.mix(CENTRIFUGE_BUILD.out.versions.first())
        ch_centrifuge_output = CENTRIFUGE_BUILD.out.cf
    } else {
        ch_centrifuge_output = Channel.empty()
    }

    //
    // Module: Run MALT/BUILD
    //

    if ( params.build_malt ) {

        // The map DB file comes zipped (for some reason) from MEGAN6 website
        if ( file(params.malt_mapdb).extension == 'zip' ) {
            ch_malt_mapdb = UNZIP( [ [], params.malt_mapdb ] ).unzipped_archive.map{ meta, file -> [ file ] }
        } else {
            ch_malt_mapdb = file(params.malt_mapdb)
        }

        if ( params.malt_sequencetype == 'Protein') {
            ch_input_for_malt = ch_prepped_aa_fastas.map{ meta, file -> file }
        } else {
            ch_input_for_malt = ch_prepped_dna_fastas.map{ meta, file -> file }
        }

        MALT_BUILD (ch_input_for_malt, [], ch_malt_mapdb)
        ch_versions = ch_versions.mix(MALT_BUILD.out.versions.first())
        ch_malt_output = MALT_BUILD.out.index
    } else {
        ch_malt_output = Channel.empty()
    }

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowCreatetaxdb.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowCreatetaxdb.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()

    emit:
    versions            = CUSTOM_DUMPSOFTWAREVERSIONS.out.versions
    multiqc_report_html = MULTIQC.out.report
    centrifuge_database = ch_centrifuge_output
    diamond_database    = ch_diamond_output
    kaiju_database      = ch_kaiju_output
    malt_database       = ch_malt_output
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

workflow.onError {
    if (workflow.errorReport.contains("Process requirement exceeds available memory")) {
        println("🛑 Default resources exceed availability 🛑 ")
        println("💡 See here on how to configure pipeline: https://nf-co.re/docs/usage/configuration#tuning-workflow-resources 💡")
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
