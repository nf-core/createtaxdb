process SEQKIT_BATCH_RENAME {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0'
        : 'biocontainers/seqkit:2.9.0--h9ee0642_0'}"

    input:
    tuple val(meta), path(fastx)
    val replace_expression

    output:
    tuple val(meta), path("renamed_files/*"), emit: fastx
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def replace_string = replace_expression.join(' ')

    """
    mkdir -p renamed_files

    echo "${replace_string}" | tr ' ' '\\n' > replace.tsv

    while IFS=\$'\\t' read -r fasta_name pattern_str replace_str out_fname; do
        seqkit \\
            replace \\
            ${args} \\
            --threads ${task.cpus} \\
            -i \$fasta_name \\
            -p \$pattern_str \\
            -r \$replace_str \\
            -o renamed_files/\$out_fname
    done < replace.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """

    stub:

    def replace_string = replace_expression.join(' ')

    """
    mkdir -p renamed_files
    echo "${replace_string}" | tr ' ' '\\n' > replace.tsv

    while IFS=\$'\\t' read -r fasta_name pattern_str replace_str out_fname; do
        touch renamed_files/\$out_fname
    done < replace.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
