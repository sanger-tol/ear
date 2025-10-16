#!/usr/bin/env nextflow

include { GUNZIP } from '../../../modules/nf-core/gunzip/main'

workflow YAML_INPUT {
    take:
    input_file // params.input

    main:
    ch_versions = Channel.empty()

    def inputs = new groovy.yaml.YamlSlurper().parse(file(input_file, checkIfExists: true))

    //
    // LOGIC: UN ZIP THE INPUT FILES
    //
    def ch_hap1 = Channel.fromPath(inputs.reference_hap1, checkIfExists: true)
        .map { fasta -> tuple([id: inputs.assembly_id, file: 'hap1'], fasta) }
    def ch_hap2 = inputs.reference_hap2
        ? Channel.fromPath(inputs.reference_hap2, checkIfExists: true).map { fasta -> tuple([id: inputs.assembly_id, file: 'hap2'], fasta) }
        : Channel.empty()
    def ch_haplotigs = inputs.reference_haplotigs
        ? Channel.fromPath(inputs.reference_haplotigs, checkIfExists: true).map { fasta -> tuple([id: inputs.assembly_id, file: 'haplotigs'], fasta) }
        : Channel.empty()
    GUNZIP(ch_hap1.mix(ch_hap2, ch_haplotigs).filter { _meta, fasta -> fasta.endsWith('.gz') })
    ch_versions = ch_versions.mix(GUNZIP.out.versions.first())

    reference_hap1 = ch_hap1
        .filter { _meta, fasta -> !fasta.endsWith('.gz') }
        .mix(GUNZIP.out.gunzip.filter { meta, _fasta -> meta.file == 'hap1' })
        .map { meta, fasta -> tuple(meta.subMap('id'), fasta) }
    reference_hap2 = ch_hap2
        .filter { _meta, fasta -> !fasta.endsWith('.gz') }
        .mix(GUNZIP.out.gunzip.filter { meta, _fasta -> meta.file == 'hap2' })
        .map { _meta, fasta -> fasta }
    reference_haplotigs = ch_haplotigs
        .filter { _meta, fasta -> !fasta.endsWith('.gz') }
        .mix(GUNZIP.out.gunzip.filter { meta, _fasta -> meta.file == 'haplotigs' })
        .map { _meta, fasta -> fasta }

    emit:
    sample_id               = Channel.of([id: inputs.assembly_id])
    longread_type           = Channel.of(inputs.longread.type)
    longread_dir            = Channel.fromPath(inputs.longread.dir, checkIfExists: true, type: 'dir')
    reference_hap1
    reference_hap2
    reference_haplotigs
    cpretext_aligner        = Channel.of(inputs.curationpretext.aligner)
    cpretext_telomere_motif = Channel.of([id: inputs.assembly_id], inputs.curationpretext.telomere_motif)
    cpretext_hic_dir        = Channel.fromPath(inputs.curationpretext.hic_dir, checkIfExists: true, type: 'dir')
    fastk_hist              = Channel.fromPath(inputs.merquryfk.fastk_hist, checkIfExists: true)
    fastk_ktab              = Channel.fromPath(inputs.merquryfk.fastk_ktab, hidden: true).collect() // Collect as a list
    btk_nt_database         = Channel.fromPath(inputs.btk.nt_database, checkIfExists: true)
    btk_nt_database_prefix  = Channel.of(inputs.btk.nt_database_prefix)
    btk_nr_diamond_database = Channel.fromPath(inputs.btk.diamond_nr_database_path, checkIfExists: true)
    btk_un_diamond_database = Channel.fromPath(inputs.btk.diamond_uniprot_database_path, checkIfExists: true)
    btk_ncbi_taxonomy_path  = Channel.fromPath(inputs.btk.ncbi_taxonomy_path, checkIfExists: true)
    btk_taxid               = Channel.of(inputs.btk.taxid)
    btk_gca_accession       = Channel.of(inputs.btk.gca_accession)
    busco_lineages          = Channel.of(inputs.btk.lineages)
    busco_config            = inputs.btk.config ? Channel.fromPath(inputs.btk.config, checkIfExists: true) : Channel.empty()
    versions                = ch_versions
}
