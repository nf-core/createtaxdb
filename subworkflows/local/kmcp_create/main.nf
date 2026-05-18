include { KMCP_COMPUTE } from '../../../modules/nf-core/kmcp/compute/main'
include { KMCP_INDEX   } from '../../../modules/nf-core/kmcp/index/main'

workflow KMCP_CREATE {
    take:
    ch_ungrouped_dna_fastas // channel: [ [ val(meta), [ fasta ], [ val(meta), [ fasta ], [ val(meta), [ fasta ] ]
    ch_grouped_dna_fastas // channel: [ val(meta), [ fasta, fasta, fasta ] ]
    file_taxonomy_nodesdmp // channel: [ nodes.dmp ]
    file_taxonomy_namesdmp // channel: [ names.dmp ]

    main:

    // Create the required special taxonomy file
    ch_kmcp_reftotaxid = ch_ungrouped_dna_fastas
        .map { meta, fasta ->
            [fasta.baseName, meta.taxid]
        }
        .collectFile(
            name: "kmcp_ref2taxid.map",
            newLine: true,
        ) { line ->
            line.join('\t')
        }

    KMCP_COMPUTE(ch_grouped_dna_fastas)

    KMCP_INDEX(
        KMCP_COMPUTE.out.outdir,
        [
            [],
            [
                file_taxonomy_nodesdmp,
                file_taxonomy_namesdmp,
            ],
        ],
        ch_kmcp_reftotaxid.map { file -> [[], file] },
    )

    emit:
    db = KMCP_INDEX.out.kmcp // channel: [ val(meta), [ db ] ]
}
