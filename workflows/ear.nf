/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { NEXTFLOW_RUN as CURATIONPRETEXT   } from '../modules/local/nextflow/run'
include { NEXTFLOW_RUN as BLOBTOOLKIT       } from '../modules/local/nextflow/run'
include { SANGER_TOL_BTK                    } from '../modules/local/sanger_tol_btk'

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

    //
    // MODULE: Run Sanger-ToL/CurationPretext
    //         - This was built using: https://github.com/mahesh-panchal/nf-cascade
    //
    reference = YAML_INPUT.out.reference_path.get()
    hic_dir = YAML_INPUT.out.cpretext_hic_dir_raw.get()
    longread_dir = YAML_INPUT.out.longread_dir.get()

    CURATIONPRETEXT(
        "sanger-tol/curationpretext",
        [
            "-r 1.0.0",
            "--input",
            reference,
            "--longread",
            longread_dir,
            "--cram",
            hic_dir,
            "-profile singularity,sanger"
        ].join(" ").trim(), // workflow opts
        Channel.value([]),  //readWithDefault( params.demo.params_file, Channel.value([]) ), // params file
        Channel.value([]),  // samplesheet - not used by this pipeline
        Channel.value([])   //readWithDefault( params.demo.add_config, Channel.value([]) ),  // custom config
        //"$params.outdir/curationpretext",
    )

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

    //
    // LOGIC:  REFORMAT A BUNCH OF CHANNELS FOR MERQUERYFK
    //

    if (params.reference_hap2) {
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

        MERQURYFK(
            merquryfk_input
        )
    }

    //
    // LOGIC: SANGER-TOL/BLOBTOOLKIT expects the pacbio data to be already mapped -> this has been changed but seeing as BTK and genomenote need it then we may as well keep it.
    //          This is also a requirement for genomenote
    //
    platform = YAML_INPUT.out.longread_type

    YAML_INPUT.out.sample_id
        .combine(YAML_INPUT.out.longread_dir)
        .map{ sample, dir ->
            tuple([id: sample], dir )
        }
        .set {pacbio_tuple}

    if ( platform.filter { it == "hifi" } || platform.filter { it == "clr" } || platform.filter { it == "ont" } ) {
        //
        // SUBWORKFLOW: SINGLE END MAPPING FOR ALIGNING LONGREAD DATA
        //
        SE_MAPPING (
            YAML_INPUT.out.reference_hap1,
            YAML_INPUT.out.pacbio_tuple,
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
            YAML_INPUT.out.reference_hap1,
            YAML_INPUT.out.pacbio_tuple,
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
        YAML_INPUT.out.reference_hap1
    )
    ch_versions = ch_versions.mix( SAMTOOLS_SORT.out.versions )

    //
    // MODULE: GENERATE_SAMPLESHEET creates a csv for the blobtoolkit pipeline
    //
    YAML_INPUT.out.sample_id
        .combine(merged_bam)
        .map{ sample_id, pacbio_meta, pacbio_path ->
            tuple(  [id: sample_id],
                    pacbio_path
            )
        }
        .set { mapped_bam }


    GENERATE_SAMPLESHEET(
        mapped_bam
    )
    ch_versions = ch_versions.mix( GENERATE_SAMPLESHEET.out.versions )

    //
    // MODULE: Run Sanger-ToL/BlobToolKit
    //
    YAML_INPUT.out.reference_hap1.view{ it -> "Reference: $it"}
    mapped_bam.view{ it -> "samplesheet: $it"}
    GENERATE_SAMPLESHEET.out.csv.view{ it -> "samplesheetcsv: $it"}
    YAML_INPUT.out.btk_un_diamond_database.view{ it -> "un diamond: $it"}
    YAML_INPUT.out.btk_nt_database.view{ it -> "nt diamond: $it"}
    YAML_INPUT.out.btk_ncbi_taxonomy_path.view{ it -> "Taxdump: $it"}
    YAML_INPUT.out.btk_yaml.view{ it -> "btk_yaml: $it"}
    YAML_INPUT.out.busco_lineages.view{ it -> "lineages: $it"}
    YAML_INPUT.out.btk_taxid.view{ it -> "TAXID: $it"}

    SANGER_TOL_BTK (
        YAML_INPUT.out.reference_hap1,
        mapped_bam,
        GENERATE_SAMPLESHEET.out.csv,
        YAML_INPUT.out.btk_un_diamond_database,
        YAML_INPUT.out.btk_nt_database,
        YAML_INPUT.out.btk_un_diamond_database,
        [],
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
