/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Subpipeline imports
include { SANGER_TOL_BTK            } from '../modules/local/sanger-tol/blobtoolkit/main'
include { SANGER_TOL_CPRETEXT       } from '../modules/local/sanger-tol/curationpretext/main'

// Module imports
include { CAT_CAT                   } from '../modules/nf-core/cat/cat/main'
include { GENERATE_SAMPLESHEET      } from '../modules/local/generate_samplesheet/main'
include { GFASTATS                  } from '../modules/nf-core/gfastats/main'
include { MERQURYFK_MERQURYFK       } from '../modules/nf-core/merquryfk/merquryfk/main'

// Plugin imports
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_ear_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EAR {

    take:
    ch_sample_id
    ch_reference_hap1
    ch_reference_hap2
    ch_reference_haplotigs
    ch_fastk_hist
    ch_fastk_ktab
    ch_longread_dir
    ch_cpretext_hic_dir
    ch_cpretext_telomotif
    ch_cpretext_aligner
    ch_btk_read_layout
    ch_btk_un_diamond_db
    ch_btk_nt_db
    ch_btk_ncbi_taxonomy_path
    ch_btk_taxid
    ch_busco_lineages
    ch_busco_config

    main:
    ch_versions     = Channel.empty()
    ch_align_bam    = Channel.empty()

    //
    // NOTE: THIS STAYS HERE | MOVING IT INTO PIPELINE INIT BREAKS IT
    // LOGIC: SPLITS INPUT STEPS INTO A LIST THAT CONTROLLS PROCESSES ON EXISTENCE
    //
    exclude_steps   = params.steps ? params.steps.split(",") : "NONE"
    full_list       = ["btk", "cpretext", "merquryfk", "NONE"]

    if (!full_list.containsAll(exclude_steps)) {
        exit 1, "There is an extra argument given on Command Line: \nCheck contents of: $exclude_steps\nMaster list is: $full_list"
    }

    //
    // LOGIC: IF HAPLOTIGS IS EMPTY THEN PASS ON HALPLOTYPE ASSEMBLY
    //          IF HAPLOTIGS EXISTS THEN MERGE WITH HAPLOTYPE ASSEMBLY
    //
    if (ch_reference_haplotigs.ifEmpty(true)) {
        ch_sample_id
            .combine(ch_reference_hap2)
            .combine(ch_reference_haplotigs)
            .map{ sample_id, file1, file2 ->
                tuple(
                    [   id: sample_id   ],
                    [   file1,
                        file2
                    ]
                )
            }
            .set {
                cat_cat_input
            }

        CAT_CAT(cat_cat_input)
        ch_versions = ch_versions.mix( CAT_CAT.out.versions )

        ch_haplotype_fasta  = CAT_CAT.out.file_out
    } else {
        ch_haplotype_fasta = ch_reference_hap2
    }


    //
    // MODULE: ASSEMBLY STATISTICS FOR THE FASTA
    //
    GFASTATS(
        ch_reference_hap1,
        "fasta",
        [],
        [],
        [[],[]],
        [[],[]],
        [[],[]],
        [[],[]]
    )
    ch_versions     = ch_versions.mix( GFASTATS.out.versions )


    //
    // LOGIC: STEP TO STOP MERQURY_FK RUNNING IF SPECIFIED BY USER
    //
    if (!exclude_steps.contains("merquryfk")) {
        //
        // LOGIC:  REFORMAT A BUNCH OF CHANNELS FOR MERQUERYFK
        //
        ch_reference_hap1
            .combine(ch_haplotype_fasta)
            .combine(ch_fastk_hist)
            .combine(ch_fastk_ktab)
            .map{ meta1, primary, meta2, haplotigs, fastk_hist, fastk_ktab ->
                tuple(  meta1,
                        fastk_hist,
                        fastk_ktab,
                        primary,
                        haplotigs
                )
            }
            .set { merquryfk_input }

        //
        // MODULE: MERQURYFK PLOTS OF GENOME
        //
        MERQURYFK_MERQURYFK(
            merquryfk_input,
            [],
            []
        )
        ch_versions     = ch_versions.mix( MERQURYFK_MERQURYFK.out.versions )
    }


    //
    // LOGIC: STEP TO STOP BTK RUNNING IF SPECIFIED BY USER
    //
    if (!exclude_steps.contains("btk")) {
        //
        // MODULE: GENERATE_SAMPLESHEET creates a csv for the blobtoolkit pipeline
        //
        GENERATE_SAMPLESHEET(
            ch_reference_hap1,
            ch_longread_dir,
            ch_btk_read_layout
        )
        ch_versions     = ch_versions.mix( GENERATE_SAMPLESHEET.out.versions )


        //
        // MODULE: Run Sanger-ToL/BlobToolKit
        //
        SANGER_TOL_BTK (
            ch_reference_hap1,
            GENERATE_SAMPLESHEET.out.csv,
            ch_longread_dir,
            ch_btk_un_diamond_db,
            ch_btk_nt_db,
            ch_btk_un_diamond_db,
            ch_btk_ncbi_taxonomy_path,
            ch_busco_lineages,
            ch_btk_taxid,
            'GCA_0001',
            ch_busco_config
        )
        ch_versions     = ch_versions.mix(SANGER_TOL_BTK.out.versions)
    }


    //
    // LOGIC: STEP TO STOP CURATION_PRETEXT RUNNING IF SPECIFIED BY USER
    //
    if (!exclude_steps.contains("cpretext")) {

        //
        // MODULE: Run SANGER-TOL/CurationPretext
        //
        SANGER_TOL_CPRETEXT(
            ch_reference_hap1,
            ch_longread_dir,
            ch_cpretext_hic_dir,
            ch_cpretext_telomotif.map{it -> it[1]},
            ch_cpretext_aligner,
            []
        )
        ch_versions     = ch_versions.mix( SANGER_TOL_CPRETEXT.out.versions )
    }


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'ear_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
