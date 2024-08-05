#!/usr/bin/env nextflow

import groovy.yaml.YamlSlurper

workflow YAML_INPUT {
    take:
    input_file          // params.input

    main:
    ch_versions             = Channel.empty()

    inputs                  = new YamlSlurper().parse(file(params.input))

    emit:
    //
    // LOGIC: Building generic channels
    //
    sample_id               = Channel.of(inputs.assembly_id)
    longread_type           = Channel.of(inputs.longread.type)
    longread_dir            = Channel.of(inputs.longread.dir)
    reference               = Channel.fromPath([inputs.assembly_id], inputs.reference_file, checkIfExists: true)

    //
    // LOGIC: Building CurationPretext specific channels
    //
    cpretext_aligner        = Channel.of(inputs.curationpretext.aligner)
    cpretext_telomere_motif = Channel.of([inputs.assembly_id], inputs.curationpretext.telomere_motif)
    cpretext_hic_dir        = Channel.of([inputs.assembly_id], inputs.curationpretext.hic_dir)

    //
    // LOGIC: Building BlobToolKit specific channels
    //
    btk_nt_database         = Channel.of([inputs.assembly_id], inputs.btk.nt_database)
    btk_nt_database_prefix  = Channel.of(inputs.btk.nt_database_prefix)
    btk_nt_diamond_database = Channel.of(inputs.btk.diamond_nt_database_path)
    btk_un_diamond_database = Channel.of(inputs.btk.diamond_uniprot_database_path)
    btk_ncbi_taxonomy_path  = Channel.of(inputs.btk.ncbi_taxonomy_path)
    btk_ncbi_lineage_path   = Channel.of(inputs.btk.ncbi_rankedlineage_path)
    btk_btk_yaml            = Channel.of(inputs.btk.btk_yaml)
    btk_taxid               = Channel.of([inputs.assembly_id], inputs.btk.taxid)
    btk_gca_accession       = Channel.of(inputs.btk.gca_accession)

    versions                = ch_versions.ifEmpty(null)
}
