process SEQKIT_BATCH_RENAME {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0'
        : 'biocontainers/seqkit:2.9.0--h9ee0642_0'}"

    input:
    tuple val(meta), path(fastx), path(replace_tsv)

    output:
    tuple val(meta), path("renamed_files/*"), emit: fastx
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    while IFS=\$'\\t' read -r fasta_name replace_str out_fname ; do
        seqkit \\
            replace \\
            ${args} \\
            --threads ${task.cpus} \\
            -i \$fasta_name \\
            -r \$replace_str \\
            -o renamed_files/\$out_fname \\
    done < ${replace_tsv}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extension = "fastq"
    if ("${fastx}" ==~ /.+\.fasta|.+\.fasta.gz|.+\.fa|.+\.fa.gz|.+\.fas|.+\.fas.gz|.+\.fna|.+\.fna.gz/) {
        extension = "fasta"
    }
    def endswith = task.ext.suffix ?: "${extension}.gz"

    """
    echo "" | gzip > ${prefix}.${endswith}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
