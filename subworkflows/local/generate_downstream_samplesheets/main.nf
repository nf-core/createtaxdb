//
// Subworkflow with functionality specific to the nf-core/createtaxdb pipeline
//

workflow SAMPLESHEET_TAXPROFILER {
    take:
    ch_databases

    main:
    ch_versions = channel.empty()
    format = 'csv'

    ch_list_for_samplesheet = ch_databases.map { meta, db ->
        def tool = meta.tool
        def db_name = meta.id + '-' + meta.tool
        def db_params = ""
        def db_type = ""
        def db_path = file(params.outdir).toString() + '/' + meta.tool + '/' + db.getName()
        [tool: tool, db_name: db_name, db_params: db_params, db_type: db_type, db_path: db_path]
    }

    if (params.build_bracken && params.build_kraken2) {
        log.warn("Generated nf-core/taxprofiler samplesheet will only have a row for bracken. If Kraken2 is wished to be executed separately in nf-core/taxprofiler, duplicate the bracken row yourself and update tool column to Kraken2!")
    }

    ch_final_samplesheet = channelToSamplesheet(ch_list_for_samplesheet, "${params.outdir}/downstream_samplesheets/databases-taxprofiler", format)

    emit:
    samplesheet_taxprofiler = ch_final_samplesheet
    versions                = ch_versions
}

workflow GENERATE_DOWNSTREAM_SAMPLESHEETS {
    take:
    ch_databases

    main:
    ch_versions = channel.empty()
    def downstreampipeline_names = params.generate_pipeline_samplesheets.split(",")

    if (downstreampipeline_names.contains('taxprofiler')) {
        SAMPLESHEET_TAXPROFILER(ch_databases)
        ch_final_samplesheet = SAMPLESHEET_TAXPROFILER.out.samplesheet_taxprofiler
        ch_versions = ch_versions.mix(SAMPLESHEET_TAXPROFILER.out.versions)
    }

    emit:
    samplesheet = ch_final_samplesheet
    versions    = ch_versions
}

def channelToSamplesheet(ch_list_for_samplesheet, path, format) {
    def format_sep = [csv: ",", tsv: "\t", txt: "\t"][format]

    def ch_header = ch_list_for_samplesheet

    def ch_samplesheet = ch_header
        .first()
        .map { row -> row.keySet().join(format_sep) }
        .concat(ch_list_for_samplesheet.map { row -> row.values().join(format_sep) })
        .collectFile(
            name: "${path}.${format}",
            newLine: true,
            sort: false,
        )

    return ch_samplesheet
}
