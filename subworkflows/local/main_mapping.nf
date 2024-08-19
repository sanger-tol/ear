include { SE_MAPPING        } from './se_mapping'
include { PE_MAPPING        } from './pe_mapping'

include { SAMTOOLS_SORT     } from '../../modules/nf-core/samtools/sort/main'


workflow MAIN_MAPPING {

    take:
    sample_id               // val(sample_id)
    platform                // val(data_type)
    reference_hap1          // tuple val(meta), path(reference)
    pacbio_tuple            // tuple val(meta), path(longread_path)

    main:
    ch_align_bam    = Channel.empty()
    ch_versions     = Channel.empty()

    //
    // LOGIC: SANGER-TOL/BLOBTOOLKIT expects the pacbio data to be already mapped -> this has been changed but seeing as BTK and genomenote need it then we may as well keep it.
    //          This is also a requirement for genomenote
    //

    if ( platform.filter { it == "hifi" } || platform.filter { it == "clr" } || platform.filter { it == "ont" } ) {
        //
        // SUBWORKFLOW: SINGLE END MAPPING FOR ALIGNING LONGREAD DATA
        //
        SE_MAPPING (
            reference_hap1,
            pacbio_tuple,
            platform
        )
        ch_versions = ch_versions.mix(SE_MAPPING.out.versions)

        ch_align_bam
            .mix( SE_MAPPING.out.mapped_bam )
            .set { merged_bam }
    }
    else if ( platform.filter { it == "illumina" } ) {
        //
        // SUBWORKFLOW: PAIRED END MAPPING FOR ALIGNING LONGREAD DATA
        //
        PE_MAPPING  (
            reference_hap1,
            pacbio_tuple,
            platform
        )
        ch_versions = ch_versions.mix(PE_MAPPING.out.versions)

        ch_align_bam
            .mix( PE_MAPPING.out.mapped_bam )
            .set { merged_bam }
    }

    //
    // MODULE: SORT MAPPED BAM
    //
    SAMTOOLS_SORT (
        merged_bam,
        reference_hap1
    )
    ch_versions = ch_versions.mix( SAMTOOLS_SORT.out.versions )

    sample_id
        .combine(merged_bam)
        .map{ sample_id, pacbio_meta, pacbio_path ->
            tuple(  [id: sample_id],
                    pacbio_path
            )
        }
        .set { mapped_bam }

    emit:
    mapped_bam                        // channel: tuple val(meta), path(mapped_bam)
    versions       = ch_versions      // channel: [ path(versions.yml) ]

}