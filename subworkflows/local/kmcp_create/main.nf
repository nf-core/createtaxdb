include { KMCP_COMPUTE } from '../../../modules/nf-core/kmcp/compute/main'
include { KMCP_INDEX   } from '../../../modules/nf-core/kmcp/index/main'

workflow KMCP_CREATE {
    take:
    ch_fasta // channel: [ val(meta), [ fasta ] ]

    main:

    ch_versions = channel.empty()

    KMCP_COMPUTE(ch_fasta)
    ch_versions = ch_versions.mix(KMCP_COMPUTE.out.versions.first())

    KMCP_INDEX(KMCP_COMPUTE.out.outdir)
    ch_versions = ch_versions.mix(KMCP_INDEX.out.versions.first())

    emit:
    db       = KMCP_INDEX.out.kmcp // channel: [ val(meta), [ db ] ]
    versions = ch_versions // channel: [ versions.yml ]
}
