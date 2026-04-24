include { KMCP_COMPUTE } from '../../../modules/nf-core/kmcp/compute/main'
include { KMCP_INDEX   } from '../../../modules/nf-core/kmcp/index/main'

workflow KMCP_CREATE {
    take:
    ch_fasta // channel: [ val(meta), [ fasta ] ]
    file_taxonomy_nodesdmp // channel: [ nodes.dmp ]
    file_taxonomy_namesdmp // channel: [ names.dmp ]
    file_ref2taxid // channel: [ file_ref2taxid.map ]

    main:
    KMCP_COMPUTE(ch_fasta)

    KMCP_INDEX(
        KMCP_COMPUTE.out.outdir,
        [
            [],
            [
                file_taxonomy_nodesdmp,
                file_taxonomy_namesdmp,
            ],
        ],
        file_ref2taxid.map { file -> [[], file] },
    )

    emit:
    db = KMCP_INDEX.out.kmcp // channel: [ val(meta), [ db ] ]
}
