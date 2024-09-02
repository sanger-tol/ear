/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Subpipeline imports
include { SANGER_TOL_BTK                    } from '../modules/local/sanger_tol_btk'
include { SANGER_TOL_CPRETEXT               } from '../modules/local/sanger_tol_cpretext'

// Subworkflow imports
include { YAML_INPUT                        } from '../subworkflows/local/yaml_input'
include { MAIN_MAPPING                      } from '../subworkflows/local/main_mapping'

// Module imports
include { CAT_CAT                           } from '../modules/nf-core/cat/cat/main' 
include { GENERATE_SAMPLESHEET              } from '../modules/local/generate_samplesheet'
include { GFASTATS                          } from '../modules/nf-core/gfastats/main'
include { MERQURYFK_MERQURYFK               } from '../modules/nf-core/merquryfk/merquryfk/main'

// Plugin imports
include { paramsSummaryMap                  } from 'plugin/nf-validation'
include { paramsSummaryMultiqc              } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML            } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText            } from '../subworkflows/local/utils_nfcore_ear_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EAR {

    take:
    ch_input

    main:
    params.mapped   = false
    ch_versions     = Channel.empty()
    ch_align_bam    = Channel.empty()


    //
    // MODULE: YAML_INPUT
    //          - YAML_INPUT SHOULD BE REWORKED TO BE SMARTER
    //
    YAML_INPUT(ch_input)


    //
    // LOGIC: IF HAPLOTIGS IS EMPTY THEN PASS ON HALPLOTYPE ASSEMBLY
    //          IF HAPLOTIGS EXISTS THEN MERGE WITH HAPLOTYPE ASSEMBLY
    // 
    if (YAML_INPUT.out.reference_haplotigs.ifEmpty(true)) {
        YAML_INPUT.out.sample_id
            .combine(YAML_INPUT.out.reference_hap2)
            .combine(YAML_INPUT.out.reference_haplotigs)
            .map{ sample_id, file1, file2 ->
                tuple(
                    [   id: sample_id   ],
                    [file1, file2]
                )
            }
            .set {
                cat_cat_input
            }

        CAT_CAT(cat_cat_input)
        ch_versions = ch_versions.mix( CAT_CAT.out.versions )

        ch_haplotype_fasta  = CAT_CAT.out.file_out
    } else {
        ch_haplotype_fasta = YAML_INPUT.out.reference_hap2
    }

    //
    // MODULE: ASSEMBLY STATISTICS FOR THE FASTA
    //
    GFASTATS(
        YAML_INPUT.out.reference_hap1,
        "fasta",
        [],
        [],
        [],
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix( GFASTATS.out.versions )


    //
    // LOGIC:  REFORMAT A BUNCH OF CHANNELS FOR MERQUERYFK
    //
    YAML_INPUT.out.reference_hap1
        .combine(ch_haplotype_fasta)
        .combine(YAML_INPUT.out.fastk_hist)
        .combine(YAML_INPUT.out.fastk_ktab)
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
    // MERQURYFK_MERQURYFK(
    //     merquryfk_input
    // )
    // ch_versions = ch_versions.mix( MERQURYFK_MERQURYFK.out.versions )


    //
    // LOGIC: IF A MAPPED BAM FILE EXISTS AND THE FLAG `mapped` IS TRUE
    //          SKIP THE MAPPING SUBWORKFLOW
    //
    // if (!params.mapped) {
    //     //
    //     // SUBWORKFLOW: MAIN_MAPPING CONTAINS ALL THE MAPPING LOGIC
    //     //              This allows us to more esily bypass the mapping if we already have a sorted and mapped bam
    //     //
    //     MAIN_MAPPING (
    //         YAML_INPUT.out.sample_id,
    //         YAML_INPUT.out.longread_type,
    //         YAML_INPUT.out.reference_hap1,
    //         YAML_INPUT.out.pacbio_tuple,
    //     )
    //     ch_versions = ch_versions.mix( MAIN_MAPPING.out.versions )
    //     ch_mapped_bam = MAIN_MAPPING.out.mapped_bam
    // } else {
    //     ch_mapped_bam = YAML_INPUT.out.mapped_bam
    // }


    //
    // MODULE: GENERATE_SAMPLESHEET creates a csv for the blobtoolkit pipeline
    //
    // GENERATE_SAMPLESHEET(
    //     ch_mapped_bam
    // )
    // ch_versions = ch_versions.mix( GENERATE_SAMPLESHEET.out.versions )


    // //
    // // MODULE: Run Sanger-ToL/BlobToolKit
    // //
    // SANGER_TOL_BTK (
    //     YAML_INPUT.out.reference_hap1,
    //     ch_mapped_bam,
    //     GENERATE_SAMPLESHEET.out.csv,
    //     YAML_INPUT.out.btk_un_diamond_database,
    //     YAML_INPUT.out.btk_nt_database,
    //     YAML_INPUT.out.btk_un_diamond_database,
    //     YAML_INPUT.out.btk_config,
    //     YAML_INPUT.out.btk_ncbi_taxonomy_path,
    //     YAML_INPUT.out.busco_lineages,
    //     YAML_INPUT.out.btk_taxid,
    //     'GCA_0001'
    // )
    // ch_versions              = ch_versions.mix(SANGER_TOL_BTK.out.versions)


    //
    // MODULE: Run Sanger-ToL/CurationPretext
    //
    reference       = YAML_INPUT.out.reference_path.get()
    hic_dir         = YAML_INPUT.out.cpretext_hic_dir_raw.get()
    longread_dir    = YAML_INPUT.out.longread_dir.get()

    // SANGER_TOL_CPRETEXT(
    //     reference,
    //     longread_dir,
    //     hic_dir,
    //     []
    // )
    // ch_versions = ch_versions.mix( SANGER_TOL_CPRETEXT.out.versions )


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
