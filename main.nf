#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sanger-tol/ear
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/sanger-tol/ear
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { EAR                       } from './workflows/ear'
include { PIPELINE_INITIALISATION   } from './subworkflows/local/utils_nfcore_ear_pipeline'
include { PIPELINE_COMPLETION       } from './subworkflows/local/utils_nfcore_ear_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow SANGERTOL_EAR {

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
    ch_btk_un_diamond_db
    ch_btk_nt_db
    ch_btk_ncbi_taxonomy_path
    ch_btk_taxid
    ch_busco_lineages
    ch_busco_config


    main:

    //
    // WORKFLOW: Run pipeline
    //
    EAR (
        ch_sample_id,
        ch_reference_hap1,
        ch_reference_hap2,
        ch_reference_haplotigs,
        ch_fastk_hist,
        ch_fastk_ktab,
        ch_longread_dir,
        ch_cpretext_hic_dir,
        ch_cpretext_telomotif,
        ch_cpretext_aligner,
        ch_btk_un_diamond_db,
        ch_btk_nt_db,
        ch_btk_ncbi_taxonomy_path,
        ch_btk_taxid,
        ch_busco_lineages,
        ch_busco_config
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )


    //
    // WORKFLOW: Run main workflow
    //
    SANGERTOL_EAR (
        PIPELINE_INITIALISATION.out.sample_id,
        PIPELINE_INITIALISATION.out.reference_hap1,
        PIPELINE_INITIALISATION.out.reference_hap2,
        PIPELINE_INITIALISATION.out.reference_haplotigs,
        PIPELINE_INITIALISATION.out.fastk_hist,
        PIPELINE_INITIALISATION.out.fastk_ktab,
        PIPELINE_INITIALISATION.out.longread_dir,
        PIPELINE_INITIALISATION.out.cpretext_hic_dir,
        PIPELINE_INITIALISATION.out.cpretext_telomere_motif,
        PIPELINE_INITIALISATION.out.cpretext_aligner,
        PIPELINE_INITIALISATION.out.btk_un_diamond_database,
        PIPELINE_INITIALISATION.out.btk_nt_database,
        PIPELINE_INITIALISATION.out.btk_ncbi_taxonomy_path,
        PIPELINE_INITIALISATION.out.btk_taxid,
        PIPELINE_INITIALISATION.out.busco_lineages,
        PIPELINE_INITIALISATION.out.busco_config
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
    )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
