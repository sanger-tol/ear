/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// include { NEXTFLOW_RUN as CURATIONPRETEXT   } from '../modules/local/nextflow/run'
// include { NEXTFLOW_RUN as BLOBTOOLKIT       } from '../modules/local/nextflow/run'
include { SANGER_TOL_BTK                    } from '../modules/local/sanger_tol_btk'
include { SANGER_TOL_CPRETEXT               } from '../modules/local/sanger_tol_cpretext'

include { YAML_INPUT                        } from '../subworkflows/local/yaml_input'
include { GENERATE_SAMPLESHEET              } from '../modules/local/generate_samplesheet'
include { GFASTATS                          } from '../modules/nf-core/gfastats/main'
include { MAIN_MAPPING                      } from '../subworkflows/local/main_mapping'
include { MERQURYFK_MERQURYFK               } from '../modules/nf-core/merquryfk/merquryfk/main'

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
    //
    YAML_INPUT(ch_input)

    //
    // MODULE: Run Sanger-ToL/CurationPretext
    //         - This was built using: https://github.com/mahesh-panchal/nf-cascade
    //
    reference       = YAML_INPUT.out.reference_path.get()
    hic_dir         = YAML_INPUT.out.cpretext_hic_dir_raw.get()
    longread_dir    = YAML_INPUT.out.longread_dir.get()

    // CURATIONPRETEXT(
    //     "sanger-tol/curationpretext",
    //     [
    //         "-r 1.0.0",
    //         "--input",
    //         reference,
    //         "--longread",
    //         longread_dir,
    //         "--cram",
    //         hic_dir,
    //         "-profile singularity,sanger"
    //     ].join(" ").trim(), // workflow opts
    //     Channel.value([]),  //readWithDefault( params.demo.params_file, Channel.value([]) ), // params file
    //     Channel.value([]),  // samplesheet - not used by this pipeline
    //     Channel.value([])   //readWithDefault( params.demo.add_config, Channel.value([]) ),  // custom config
    // )

    SANGER_TOL_CPRETEXT(
        reference,
        longread_dir,
        hic_dir,
        []
    )
    ch_versions = ch_versions.mix( SANGER_TOL_CPRETEXT.out.versions )


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
        .combine(YAML_INPUT.out.reference_hap2)
        .combine(YAML_INPUT.out.fastk_hist)
        .combine(YAML_INPUT.out.fastk_ktab)
        .map{ meta, primary, haplotigs, fastk_hist, fastk_ktab ->
            tuple(  meta,
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
        merquryfk_input
    )
    ch_versions = ch_versions.mix( MERQURYFK_MERQURYFK.out.versions )


    ch_mapped_bam = YAML_INPUT.out.mapped_bam
    if (!params.mapped) {
        //
        // SUBWORKFLOW: MAIN_MAPPING CONTAINS ALL THE MAPPING LOGIC
        //              This allows us to more esily bypass the mapping if we already have a sorted and mapped bam
        //
        MAIN_MAPPING (
            YAML_INPUT.out.sample_id,
            YAML_INPUT.out.longread_type,
            YAML_INPUT.out.reference_hap1,
            YAML_INPUT.out.pacbio_tuple,
        )
        ch_versions = ch_versions.mix( MAIN_MAPPING.out.versions )
        ch_mapped_bam = MAIN_MAPPING.out.mapped_bam
    }

    //
    // MODULE: GENERATE_SAMPLESHEET creates a csv for the blobtoolkit pipeline
    //

    GENERATE_SAMPLESHEET(
        ch_mapped_bam
    )
    ch_versions = ch_versions.mix( GENERATE_SAMPLESHEET.out.versions )

    //
    // MODULE: Run Sanger-ToL/BlobToolKit
    //
    SANGER_TOL_BTK (
        YAML_INPUT.out.reference_hap1,
        ch_mapped_bam,
        GENERATE_SAMPLESHEET.out.csv,
        YAML_INPUT.out.btk_un_diamond_database,
        YAML_INPUT.out.btk_nt_database,
        YAML_INPUT.out.btk_un_diamond_database,
        YAML_INPUT.out.btk_config,
        YAML_INPUT.out.btk_ncbi_taxonomy_path,
        YAML_INPUT.out.btk_yaml,
        YAML_INPUT.out.busco_lineages,
        YAML_INPUT.out.btk_taxid,
        'GCA_0001'
    )
    ch_versions              = ch_versions.mix(SANGER_TOL_BTK.out.versions)

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


//
// MODULE: THERE ARE TWO DATABASES WHICH ARE FREQUENTLY THE SAME DATABASE
//          THIS STOPS NAME CONFLICTS BEFORE THEY ARE COPIED TO THE SAME PLACE
//
process RenameDatabase {
    tag "Rename DMND Database"
    executor 'local'

    input:
    db_path

    output:
    path "UN.dmnd"

    "true"
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
