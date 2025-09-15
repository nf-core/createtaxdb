// TODO nf-core: If in doubt look at other nf-core/subworkflows to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/subworkflows
//               You can also ask for help via your pull request or on the #subworkflows channel on the nf-core Slack workspace:
//               https://nf-co.re/join

include { SOURMASH_SKETCH      } from '../../../modules/nf-core/sourmash/sketch/main'
include { SOURMASH_INDEX     } from '../../../modules/nf-core/sourmash/index/main'

workflow SOURMASH_CREATE {

    take:
    ch_genomes // channel: [ val(meta), fasta ]
    batch_size
    kmer_size

    main:
    
    ch_versions = Channel.empty()
    ch_genomes.dump(pretty: true)

    /* Let sourmash sketch `batch_size` signatures at a time.
     * This is a compromise between sourmash being single threaded and the overhead
     * of starting a separate process (container) for each batch.
     */
    def ch_sketch_input = ch_genomes
        // Remove the meta information for the batching.
        .map { _meta, genome -> genome }  // [ genome ]
        .collate(batch_size)  // [[genomes]]
        // Add meta information for the batch, including an index.
        .map { genomes, idx -> [[ id: "batch_${idx}" ], genomes ] }

    ch_sketch_input.dump(pretty: true)

    SOURMASH_SKETCH(ch_sketch_input)

    ch_versions = ch_versions.mix(SOURMASH_SKETCH.out.versions.first())

    def ch_index_input = SOURMASH_SKETCH.out.signatures
        // Remove the meta information.
        .flatMap { _meta, signatures -> signatures }  // [ signatures ]
        .collect()  // [ [signatures] ]
        // Add meta information for all signatures.
        .map { signatures -> [[ id: "all" ], signatures ] }

    ch_index_input.dump(pretty: true)

    SOURMASH_INDEX(ch_index_input, kmer_size)

    ch_versions = ch_versions.mix(SOURMASH_INDEX.out.versions.first())

    emit:
    index      = SOURMASH_INDEX.out.signature_index  // channel: [ val(meta), index ]

    versions = ch_versions                     // channel: [ versions.yml ]
}
