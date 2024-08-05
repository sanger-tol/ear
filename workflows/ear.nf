/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { NEXTFLOW_RUN as CURATIONPRETEXT   } from '../modules/local/nextflow/run'
include { NEXTFLOW_RUN as BLOBTOOLKIT       } from '../modules/local/nextflow/run'

include { YAML_INPUT                        } from '../subworkflows/local/yaml_input'
include { GENERATE_SAMPLESHEET              } from '../modules/local/generate_samplesheet'
include { GFASTATS                          } from '../modules/nf-core/gfastats/main'
include { PE_MAPPING                        } from '../subworkflows/local/pe_mapping'
include { SE_MAPPING                        } from '../subworkflows/local/se_mapping'
include { SAMTOOLS_SORT                     } from '../modules/nf-core/samtools/sort/main'

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

    ch_versions     = Channel.empty()
    ch_align_bam    = Channel.empty()

    //
    // MODULE: YAML_INPUT
    //
    YAML_INPUT(ch_input)
    reference = YAML_INPUT.out.reference
    reference.view()

    //
    // MODULE: Run Sanger-ToL/CurationPretext
    //         - This was built using: https://github.com/mahesh-panchal/nf-cascade
    //
    CURATIONPRETEXT(
        "sanger-tol/curationpretext",
        [
            "-r 1.0.0",
            "--input",
            reference,
            "--longread",
            YAML_INPUT.out.longread_dir,
            "--cram",
            YAML_INPUT.out.cpretext_hic_dir,
            "$params.outdir/curationpretext",
            "-profile singularity,sanger"
        ].join(" ").trim(),                                            // workflow opts
        Channel.value([]),  //readWithDefault( params.demo.params_file, Channel.value([]) ), // params file
        Channel.value([]),  // samplesheet - not used by this pipeline
        Channel.value([])   //readWithDefault( params.demo.add_config, Channel.value([]) ),  // custom config

    )

    //
    // MODULE: ASSEMBLY STATISTICS FOR THE FASTA
    //
    GFASTATS(
        YAML_INPUT.out.reference,
        "fasta",
        [],
        [],
        [],
        [],
        [],
        []
    )

    // //
    // // LOGIC:  REFORMAT A BUNCH OF CHANNELS FOR MERQUERYFK
    // //
    // YAML_INPUT.out.reference
    //     .combine()
    //     .combine()
    //     .combine()
    //     .map{ meta, primary, haplotigs, fastk_hist, fastk_ktab ->
    //         tuple(  meta,
    //                 fastk_hist,
    //                 fastk_ktab,
    //                 primary,
    //                 haplotigs
    //         )
    //     }
    //     .set { merquryfk_input }

    // //
    // // MODULE: MERQURYFK PLOTS OF GENOME
    // //

    // MERQURYFK(
    //     merquryfk_input
    // )

    //
    // LOGIC: SANGER-TOL/BLOBTOOLKIT expects the pacbio data to be already mapped
    //
    platform = YAML_INPUT.out.longread_type

    YAML_INPUT.out.sample_id
        .combine(YAML_INPUT.out.longread_dir)
        .set {pacbio_tuple}

    if ( platform.filter { it == "hifi" } || platform.filter { it == "clr" } || platform.filter { it == "ont" } ) {
        //
        // SUBWORKFLOW: SINGLE END MAPPING FOR ALIGNING LONGREAD DATA
        //
        SE_MAPPING (
            YAML_INPUT.out.reference,
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
            YAML_INPUT.out.reference,
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
        YAML_INPUT.out.reference
    )
    ch_versions = ch_versions.mix( SAMTOOLS_SORT.out.versions )

    //
    // MODULE: GENERATE_SAMPLESHEET creates a csv for the blobtoolkit pipeline
    //
    YAML_INPUT.out.sample_id
        .combine(merged_bam)
        .map{ sample_id, pacbio_path ->
            tuple(  [id: sample_id],
                    pacbio_path
            )
        }
        .set { samplesheet_input }


    GENERATE_SAMPLESHEET(
        samplesheet_input
    )

    //
    // MODULE: Run Sanger-ToL/BlobToolKit
    //         - This was built using: https://github.com/mahesh-panchal/nf-cascade
    //
    // BLOBTOOLKIT(
    //     "sanger-tol/blobtoolkit",
    //     [
    //         "-r 0.4.0",
    //         "--input",
    //         GENERATE_SAMPLESHEET.out.csv,
    //         "--fasta",
    //         reference,
    //         "--accession",
    //         YAML_INPUT.out.btk_gca_accession,
    //         "-taxon",
    //         YAML_INPUT.out.btk_taxid,
    //         "--taxdump",
    //         YAML_INPUT.out.btk_ncbi_taxonomy_path,
    //         "--blastp",
    //         YAML_INPUT.out.btk_nt_diamond_database,
    //         "--blastn",
    //         YAML_INPUT.out.btk_nt_database,
    //         "--blastx",
    //         YAML_INPUT.out.btk_nt_diamond_database,
    //         "$params.outdir/blobtoolkit",
    //         "-profile singularity,sanger"
    //     ].join(" ").trim(),                                                                 // workflow opts
    //     Channel.value([]),//readWithDefault( params.demo.params_file, Channel.value([]) ),  // params file
    //     Channel.value([]),//readWithDefault( params.demo.input, Channel.value([]) ),        // samplesheet
    //     Channel.value([])//readWithDefault( params.demo.add_config, Channel.value([]) ),    // custom config

    // )

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
