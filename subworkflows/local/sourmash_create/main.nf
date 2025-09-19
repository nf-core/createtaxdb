include { SOURMASH_SKETCH } from '../../../modules/nf-core/sourmash/sketch/main'
include { SOURMASH_INDEX  } from '../../../modules/nf-core/sourmash/index/main'

workflow SOURMASH_CREATE {
    take:
    ch_library    // channel: [ val(meta), [fasta] ]
    kmer_sizes
    batch_size

    main:
    ch_versions = Channel.empty()

    /*
     * Let sourmash sketch `batch_size` signatures at a time. This is a
     * compromise between sourmash being single threaded and the overhead of
     * starting a separate process (container) for each batch. We sort the
     * genomes beforehand to ensure stable batching, which enables caching. And
     * we insert a batch identifier to distinguish the output.
     */
    def ch_sketch_input = ch_library.flatMap { meta, genomes ->
        genomes
            .sort()
            .collate(batch_size)
            .withIndex(1)
            .collect { batch, idx -> [[id: "${meta.id}_${idx}", db: meta.id], batch] }
    }

    SOURMASH_SKETCH(ch_sketch_input)
    ch_versions = ch_versions.mix(SOURMASH_SKETCH.out.versions.first())

    // Drop the batch identifiers and flatten the batches. Then add the original
    // database name and index the signatures per k-mer size.
    def ch_index_input = SOURMASH_SKETCH.out.signatures
        .map { meta, signatures -> [meta.db, signatures] }
        .groupTuple()
        .map { db, signatures -> [[id: db, kmer_size: 1], signatures.flatten()] }
        .combine(kmer_sizes)
        .multiMap { meta, signatures, kmer_size ->
            signatures: [meta + [kmer_size: kmer_size], signatures]
            kmer_size: kmer_size
        }

    SOURMASH_INDEX(ch_index_input.signatures, ch_index_input.kmer_size)
    ch_versions = ch_versions.mix(SOURMASH_INDEX.out.versions.first())

    emit:
    db       = SOURMASH_INDEX.out.signature_index // channel: [ val(meta), index ]
    versions = ch_versions // channel: [ versions.yml ]
}
