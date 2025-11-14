#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/createtaxdb
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/createtaxdb
    Website: https://nf-co.re/createtaxdb
    Slack  : https://nfcore.slack.com/channels/createtaxdb
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CREATETAXDB             } from './workflows/createtaxdb'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_createtaxdb_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_createtaxdb_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_CREATETAXDB(
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_CREATETAXDB.out.multiqc_report,
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_CREATETAXDB {
    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // WORKFLOW: Run pipeline
    //
    ch_samplesheet = samplesheet

    ch_taxonomy_namesdmp = params.namesdmp ? file(params.namesdmp, checkIfExists: true) : []
    ch_taxonomy_nodesdmp = params.nodesdmp ? file(params.nodesdmp, checkIfExists: true) : []
    ch_accession2taxid = params.accession2taxid ? file(params.accession2taxid, checkIfExists: true) : []
    ch_nucl2taxid = params.nucl2taxid ? file(params.nucl2taxid, checkIfExists: true) : []
    ch_prot2taxid = params.prot2taxid ? file(params.prot2taxid, checkIfExists: true) : []
    ch_genomesizes = params.genomesizes ? file(params.genomesizes, checkIfExists: true) : []
    ch_malt_mapdb = params.malt_mapdb ? file(params.malt_mapdb, checkIfExists: true) : []

    CREATETAXDB(
        ch_samplesheet,
        ch_taxonomy_namesdmp,
        ch_taxonomy_nodesdmp,
        ch_accession2taxid,
        ch_nucl2taxid,
        ch_prot2taxid,
        ch_genomesizes,
        ch_malt_mapdb,
    )

    emit:
    multiqc_report = CREATETAXDB.out.multiqc_report // channel: /path/to/multiqc_report.html
}
