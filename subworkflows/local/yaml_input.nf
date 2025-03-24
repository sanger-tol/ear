#!/usr/bin/env nextflow

import groovy.yaml.YamlSlurper

include { GUNZIP as GUNZIP_1 } from '../../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_2 } from '../../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_3 } from '../../modules/nf-core/gunzip/main'

workflow YAML_INPUT {
    take:
    input_file                  // params.input

    main:
    ch_versions                 = Channel.empty()

    inputs                      = new YamlSlurper().parse(file(params.input))

    sample_id                   = Channel.of(inputs.assembly_id)
    longread_type               = Channel.of(inputs.longread.type)
    longread_dir                = Channel.of(inputs.longread.dir, checkIfExists: true, type: 'dir')

    //
    // LOGIC: UN ZIP THE INPUT FILES
    //
    if ( inputs.reference_hap1.endsWith('.gz') ) {
        ch_unzipped_1 = GUNZIP_1 ( [[], inputs.reference_hap1] ).gunzip.map { it -> it[1] }
        ch_versions = ch_versions.mix ( GUNZIP_1.out.versions.first() )
    } else {
        ch_unzipped_1 = Channel.fromPath(inputs.reference_hap1, checkIfExists: true)
    }

    if ( inputs.reference_hap2.endsWith('.gz') ) {
        ch_unzipped_2 = GUNZIP_2 ( [[], inputs.reference_hap2] ).gunzip
        ch_versions = ch_versions.mix ( GUNZIP_2.out.versions.first() )
    } else {
        ch_unzipped_2 = Channel.fromPath(inputs.reference_hap2, checkIfExists: true)
    }

    if ( inputs.reference_haplotigs.endsWith('.gz') ) {
        ch_unzipped_3 = GUNZIP_3 ( [[], inputs.reference_haplotigs] ).gunzip
        ch_versions = ch_versions.mix ( GUNZIP_3.out.versions.first() )
    } else {
        ch_unzipped_3 = Channel.fromPath(inputs.reference_haplotigs, checkIfExists: true)
    }

    ch_unzipped_1
        .combine(sample_id)
        .map{ref, sample_id ->
            tuple([id:sample_id], ref)
        }
        .set{reference_hap1}


    cpretext_aligner            = Channel.of(inputs.curationpretext.aligner)
    cpretext_telomere_motif_raw = Channel.of(inputs.curationpretext.telomere_motif)
    cpretext_hic_dir_raw        = Channel.of(inputs.curationpretext.hic_dir, checkIfExists: true, type: 'dir')

    sample_id
        .combine(cpretext_telomere_motif_raw)
        .map{sample, dir ->
                tuple([id: sample],
                dir
            )
        }
        .set {cpretext_telomere_motif}

    sample_id
        .combine(cpretext_hic_dir_raw)
        .map{sample, dir ->
                tuple([id: sample],
                dir
            )
        }
        .set {cpretext_hic_dir}

    emit:
    //
    // LOGIC: Building generic channels
    //
    sample_id
    longread_type                                                   // val(data)
    longread_dir                = inputs.longread.dir               // DataVariable
    reference_hap1              = reference_hap1                     // tuple (meta), path(file)
    reference_hap2              = ch_unzipped_2                     // DataVariable
    reference_haplotigs         = ch_unzipped_3

    //
    // LOGIC: Building CurationPretext specific channels
    //
    cpretext_aligner
    cpretext_telomere_motif
    cpretext_hic_dir_raw        = inputs.curationpretext.hic_dir    // DataVariable

    //
    // LOGIC: MERQURY CHANNELS
    //
    fastk_hist                  = Channel.fromPath(inputs.merquryfk.fastk_hist)
    fastk_ktab                  = Channel.fromPath(inputs.merquryfk.fastk_ktab, hidden: true)

    //
    // LOGIC: Building BlobToolKit specific channels
    //
    btk_nt_database             = Channel.of(inputs.btk.nt_database)
    btk_nt_database_prefix      = Channel.of(inputs.btk.nt_database_prefix)
    btk_nt_diamond_database     = Channel.of(inputs.btk.diamond_nr_database_path)
    btk_un_diamond_database     = Channel.of(inputs.btk.diamond_uniprot_database_path)
    btk_ncbi_taxonomy_path      = Channel.of(inputs.btk.ncbi_taxonomy_path)
    btk_ncbi_lineage_path       = Channel.of(inputs.btk.ncbi_rankedlineage_path)
    btk_taxid                   = Channel.of(inputs.btk.taxid)
    btk_gca_accession           = Channel.of(inputs.btk.gca_accession)
    busco_lineages              = Channel.of(inputs.btk.lineages)
    busco_config                = Channel.of(inputs.btk.config)

    versions                    = ch_versions.ifEmpty(null)
}
