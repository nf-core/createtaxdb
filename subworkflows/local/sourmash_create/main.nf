include { SOURMASH_SKETCH } from '../../../modules/nf-core/sourmash/sketch/main'
include { SOURMASH_INDEX  } from '../../../modules/nf-core/sourmash/index/main'

workflow SOURMASH_CREATE {
    take:
    ch_library // channel: [ val(meta), [fasta] ]
    batch_size
    kmer_size

    main:

    // The logic in this subworkflow assumes that ch_library has only one element.
    ch_library.count().map { it == 0 || it == 1 || error("Input channel 'ch_library' must contain exactly one element, but it contains ${it}.") }

    ch_versions = Channel.empty()

    // Split the single element channel into its meta and genomes components.
    def ch_library_split = ch_library.multiMap { meta, genomes ->
        db: meta
        genomes: genomes
    }

    def db_name = ""
    ch_library_split.db.map { meta -> db_name = meta.id }

    /*
     * Let sourmash sketch `batch_size` signatures at a time. This is a
     * compromise between sourmash being single threaded and the overhead of
     * starting a separate process (container) for each batch. We sort the
     * genomes beforehand to ensure stable batching, which enables caching. And
     * we insert a batch identifier to distinguish the output.
     */
    def ch_sketch_input = ch_library_split.genomes.flatMap { genomes ->
        genomes
            .sort()
            .collate(batch_size)
            .withIndex(1)
            .collect { batch, idx -> [[id: "${db_name}_${idx}"], batch] }
    }

    SOURMASH_SKETCH(ch_sketch_input)

    ch_versions = ch_versions.mix(SOURMASH_SKETCH.out.versions.first())

    // Drop the batch identifiers and flatten the batches. Then add the original
    // database name.
    def ch_index_input = SOURMASH_SKETCH.out.signatures
        .flatMap { _meta, signatures -> signatures }
        .collect()
        .map { signatures -> [[id: db_name], signatures] }

    SOURMASH_INDEX(ch_index_input, kmer_size)

    ch_versions = ch_versions.mix(SOURMASH_INDEX.out.versions.first())

    emit:
    db       = SOURMASH_INDEX.out.signature_index // channel: [ val(meta), index ]
    versions = ch_versions // channel: [ versions.yml ]
}
