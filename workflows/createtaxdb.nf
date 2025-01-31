/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                         } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                } from 'plugin/nf-schema'
include { paramsSummaryMultiqc            } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText          } from '../subworkflows/local/utils_nfcore_createtaxdb_pipeline'

// Preprocessing
include { GUNZIP as GUNZIP_DNA            } from '../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_AA             } from '../modules/nf-core/gunzip/main'
include { CAT_CAT as CAT_CAT_DNA          } from '../modules/nf-core/cat/cat/main'
include { CAT_CAT as CAT_CAT_AA           } from '../modules/nf-core/cat/cat/main'
include { CAT_CAT as CAT_CAT_AA_KAIJU     } from '../modules/nf-core/cat/cat/main'
include { SEQKIT_REPLACE                  } from '../modules/nf-core/seqkit/replace/main'

// Database building (with specific auxiliary modules)
include { CENTRIFUGE_BUILD                } from '../modules/nf-core/centrifuge/build/main'
include { DIAMOND_MAKEDB                  } from '../modules/nf-core/diamond/makedb/main'
include { GANON_BUILDCUSTOM               } from '../modules/nf-core/ganon/buildcustom/main'
include { KAIJU_MKFMI                     } from '../modules/nf-core/kaiju/mkfmi/main'
include { KRAKENUNIQ_BUILD                } from '../modules/nf-core/krakenuniq/build/main'
include { UNZIP                           } from '../modules/nf-core/unzip/main'
include { MALT_BUILD                      } from '../modules/nf-core/malt/build/main'

include { FASTA_BUILD_ADD_KRAKEN2_BRACKEN } from '../subworkflows/nf-core/fasta_build_add_kraken2_bracken/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CREATETAXDB {
    take:
    ch_samplesheet         // channel: samplesheet read in from --input
    file_taxonomy_namesdmp // file: taxonomy names file
    file_taxonomy_nodesdmp // file: taxonomy nodes file
    file_accession2taxid   // file: accession2taxid file
    file_nucl2taxid        // fle: nucl2taxid file
    file_prot2taxid        // file: prot2taxid file
    file_malt_mapdb        // file: maltmap file

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DATA PREPARATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    // PREPARE: Prepare input for single file inputs modules
    def malt_build_mode = null
    if (params.build_malt) {
        malt_build_mode = params.malt_build_options.contains('--sequenceType Protein') ? 'protein' : 'nucleotide'
    }

    if ([(params.build_malt && malt_build_mode == 'nucleotide'), params.build_centrifuge, params.build_kraken2, params.build_bracken, params.build_krakenuniq, params.build_ganon].any()) {
        // Pull just DNA sequences

        ch_dna_refs_for_singleref = ch_samplesheet
            .map { meta, fasta_dna, _fasta_aa -> [meta, fasta_dna] }
            .filter { _meta, fasta_dna ->
                fasta_dna
            }

        ch_dna_for_unzipping = ch_dna_refs_for_singleref.branch { _meta, fasta ->
            zipped: fasta.extension == 'gz'
            unzipped: true
        }

        GUNZIP_DNA(ch_dna_for_unzipping.zipped)
        ch_prepped_dna_fastas_ungrouped = GUNZIP_DNA.out.gunzip.mix(ch_dna_for_unzipping.unzipped)
        ch_prepped_dna_fastas = ch_prepped_dna_fastas_ungrouped.map { _meta, fasta -> [[id: params.dbname], fasta] }.groupTuple()
        ch_versions = ch_versions.mix(GUNZIP_DNA.out.versions.first())

        // Place in single file
        CAT_CAT_DNA(ch_prepped_dna_fastas)
        ch_versions = ch_versions.mix(CAT_CAT_DNA.out.versions.first())
        ch_singleref_for_dna = CAT_CAT_DNA.out.file_out
    }

    if ([(params.build_malt && malt_build_mode == 'protein'), params.build_kaiju, params.build_diamond].any()) {

        ch_aa_refs_for_singleref = ch_samplesheet
            .map { meta, _fasta_dna, fasta_aa -> [meta, fasta_aa] }
            .filter { _meta, fasta_aa ->
                fasta_aa
            }

        ch_aa_for_unzipping = ch_aa_refs_for_singleref.branch { _meta, fasta ->
            zipped: fasta.extension == 'gz'
            unzipped: true
        }

        GUNZIP_AA(ch_aa_for_unzipping.zipped)
        ch_prepped_aa_fastas_ungrouped = GUNZIP_AA.out.gunzip.mix(ch_aa_for_unzipping.unzipped)
        ch_prepped_aa_fastas = ch_prepped_aa_fastas_ungrouped.map { _meta, fasta -> [[id: params.dbname], fasta] }.groupTuple()
        ch_versions = ch_versions.mix(GUNZIP_AA.out.versions.first())

        if ([(params.build_malt && malt_build_mode == 'protein'), params.build_diamond].any()) {
            CAT_CAT_AA(ch_prepped_aa_fastas)
            ch_singleref_for_aa = CAT_CAT_AA.out.file_out
            ch_versions = ch_versions.mix(CAT_CAT_AA.out.versions.first())
        }
        if ([(params.build_malt && malt_build_mode == 'protein'), params.build_kaiju].any()) {
            SEQKIT_REPLACE(ch_prepped_aa_fastas_ungrouped)
            ch_versions = ch_versions.mix(SEQKIT_REPLACE.out.versions.first())
            ch_prepped_aa_fastas_kaiju = SEQKIT_REPLACE.out.fastx.map { _meta, fasta -> [[id: params.dbname], fasta] }.groupTuple()
            CAT_CAT_AA_KAIJU(ch_prepped_aa_fastas_kaiju)
            ch_versions = ch_versions.mix(CAT_CAT_AA_KAIJU.out.versions.first())
        }
    }


    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DATABASE BUILDING
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Module: Run CENTRIFUGE/BUILD

    if (params.build_centrifuge) {
        CENTRIFUGE_BUILD(ch_singleref_for_dna, file_nucl2taxid, file_taxonomy_nodesdmp, file_taxonomy_namesdmp, [])
        ch_versions = ch_versions.mix(CENTRIFUGE_BUILD.out.versions.first())
        ch_centrifuge_output = CENTRIFUGE_BUILD.out.cf
    }
    else {
        ch_centrifuge_output = Channel.empty()
    }

    // MODULE: Run DIAMOND/MAKEDB

    if (params.build_diamond) {
        DIAMOND_MAKEDB(ch_singleref_for_aa, file_prot2taxid, file_taxonomy_nodesdmp, file_taxonomy_namesdmp)
        ch_versions = ch_versions.mix(DIAMOND_MAKEDB.out.versions.first())
        ch_diamond_output = DIAMOND_MAKEDB.out.db
    }
    else {
        ch_diamond_output = Channel.empty()
    }

    if (params.build_ganon) {

        ch_ganon_input_tsv = ch_prepped_dna_fastas_ungrouped
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
        ch_ganon_tax_files = Channel.fromPath(file_taxonomy_nodesdmp).combine(Channel.fromPath(file_taxonomy_namesdmp))

        GANON_BUILDCUSTOM(ch_prepped_dna_fastas, ch_ganon_input_tsv.map { _meta, tsv -> tsv }, ch_ganon_tax_files, [])
        ch_versions = ch_versions.mix(GANON_BUILDCUSTOM.out.versions.first())
        ch_ganon_output = GANON_BUILDCUSTOM.out.db
    }
    else {
        ch_ganon_output = Channel.empty()
    }

    // MODULE: Run KAIJU/MKFMI

    if (params.build_kaiju) {
        KAIJU_MKFMI(CAT_CAT_AA_KAIJU.out.file_out, params.kaiju_keepintermediate)
        ch_versions = ch_versions.mix(KAIJU_MKFMI.out.versions.first())
        ch_kaiju_output = KAIJU_MKFMI.out.fmi
    }
    else {
        ch_kaiju_output = Channel.empty()
    }

    // SUBWORKFLOW: Kraken2 and Bracken
    // Bracken requires intermediate files, if build_bracken=true then kraken2_keepintermediate=true, otherwise an error will be raised
    // Condition is inverted because subworkflow asks if you want to 'clean' (true) or not, but pipeline says to 'keep'
    if (params.build_kraken2 || params.build_bracken) {
        def k2_keepintermediates = params.kraken2_keepintermediate || params.build_bracken ? false : true
        FASTA_BUILD_ADD_KRAKEN2_BRACKEN(ch_singleref_for_dna, file_taxonomy_namesdmp, file_taxonomy_nodesdmp, file_accession2taxid, k2_keepintermediates, params.build_bracken)
        ch_versions = ch_versions.mix(FASTA_BUILD_ADD_KRAKEN2_BRACKEN.out.versions.first())
        ch_kraken2_bracken_output = FASTA_BUILD_ADD_KRAKEN2_BRACKEN.out.db
    }
    else {
        ch_kraken2_bracken_output = Channel.empty()
    }

    // SUBWORKFLOW: Run KRAKENUNIQ/BUILD
    if (params.build_krakenuniq) {

        ch_taxdmpfiles_for_krakenuniq = Channel
            .of(file_taxonomy_namesdmp)
            .combine(Channel.of(file_taxonomy_nodesdmp))
            .map { [it] }

        Channel.of(file_nucl2taxid)
        ch_input_for_krakenuniq = ch_prepped_dna_fastas.combine(ch_taxdmpfiles_for_krakenuniq).map { meta, fastas, taxdump -> [meta, fastas, taxdump, file_nucl2taxid] }

        KRAKENUNIQ_BUILD(ch_input_for_krakenuniq, params.krakenuniq_keepintermediate)
        ch_versions = ch_versions.mix(KRAKENUNIQ_BUILD.out.versions.first())
        ch_krakenuniq_output = KRAKENUNIQ_BUILD.out.db
    }
    else {
        ch_krakenuniq_output = Channel.empty()
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
            ch_input_for_malt = ch_prepped_aa_fastas.map { _meta, file -> file }
        }
        else {
            ch_input_for_malt = ch_prepped_dna_fastas.map { _meta, file -> file }
        }

        MALT_BUILD(ch_input_for_malt, [], ch_malt_mapdb)
        ch_versions = ch_versions.mix(MALT_BUILD.out.versions.first())
        ch_malt_output = MALT_BUILD.out.index
    }
    else {
        ch_malt_output = Channel.empty()
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
    ch_multiqc_config = Channel.fromPath(
        "${projectDir}/assets/multiqc_config.yml",
        checkIfExists: true
    )
    ch_multiqc_custom_config = params.multiqc_config
        ? Channel.fromPath(params.multiqc_config, checkIfExists: true)
        : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo
        ? Channel.fromPath(params.multiqc_logo, checkIfExists: true)
        : Channel.empty()

    summary_params = paramsSummaryMap(
        workflow,
        parameters_schema: "nextflow_schema.json"
    )
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
    )
    ch_multiqc_custom_methods_description = params.multiqc_methods_description
        ? file(params.multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = Channel.value(
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
}
