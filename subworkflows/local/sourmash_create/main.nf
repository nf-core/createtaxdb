include { SOURMASH_SKETCH } from '../../../modules/nf-core/sourmash/sketch/main'
include { SOURMASH_INDEX  } from '../../../modules/nf-core/sourmash/index/main'

workflow SOURMASH_CREATE {
    take:
    ch_genomes // channel: [ val(meta), fasta ]
    batch_size
    kmer_size

    main:

    ch_versions = Channel.empty()

    /* Let sourmash sketch `batch_size` signatures at a time.
     * This is a compromise between sourmash being single threaded and the overhead
     * of starting a separate process (container) for each batch.
     */
    def ch_batches = ch_genomes
        .map { _meta, genome -> genome }
        .collate(batch_size)

    def ch_sketch_input = ch_batches
        .merge(
            ch_batches.count().flatMap { total -> (1..total).toList() }
        )
        .map { genomes, idx -> [[id: "batch_${idx}"], genomes] }

    SOURMASH_SKETCH(ch_sketch_input)

    ch_versions = ch_versions.mix(SOURMASH_SKETCH.out.versions.first())
    def ch_index_input = SOURMASH_SKETCH.out.signatures
        .flatMap { _meta, signatures -> signatures }
        .collect()
        .map { signatures -> [[id: "all"], signatures] }

    SOURMASH_INDEX(ch_index_input, kmer_size)

    ch_versions = ch_versions.mix(SOURMASH_INDEX.out.versions.first())

    emit:
    index    = SOURMASH_INDEX.out.signature_index // channel: [ val(meta), index ]
    versions = ch_versions // channel: [ versions.yml ]
}
