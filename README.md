[![GitHub Actions CI Status](https://github.com/sanger-tol/ear/actions/workflows/ci.yml/badge.svg)](https://github.com/sanger-tol/ear/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/sanger-tol/ear/actions/workflows/linting.yml/badge.svg)](https://github.com/sanger-tol/ear/actions/workflows/linting.yml)[![DOI](https://zenodo.org/badge/833605808.svg)](https://doi.org/10.5281/zenodo.13819520)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/sanger-tol/ear)

## Introduction

**sanger-tol/ear** is a bioinformatics pipeline that generates the data files required for the the generation of ERGA Assembly Reports. Sanger-tol/ear nests two other sanger-tol pipelines (blobtoolkit and curationpretext).

1. Read the input yaml file (YAML_INPUT)
2. Run GFASTATS (GFASTARS)
3. Run MERQURYFK_MERQURYFK (MERQURYFK)
4. Run MAIN_MAPPING, longread single-end/paired-end mapping
5. Run GENERATE_SAMPLESHEET, generate a csv file required for SANGER_TOL_BTK.
6. Run SANGER_TOL_BTK, also known as SANGER-TOL/BLOBTOOLKIT a subpipline for SANGER-TOL/EAR
7. Run SANGER_TOL_CPRETEXT, also known as SANGER-TOL/CURATIONPRETEXT a subpipeline for SANGER-TOL/EAR.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

The sanger-tol/ear pipeline requires a number of databases in place in order to run the blobtoolkit pipeline.
These include:

- A blast nt database
- A Diamond blast uniprot database
- A Diamond blast nr database
- An NCBI taxdump
- An NCBI rankedlineage.dmp

Next, a yaml file containing the following should then be completed:

```yaml
# General Vales for all subpiplines and modules
assembly_id: <NAME OF ASSEMBLY>
reference_hap1: <LOCATION OF PRIMARY ASSEMBLY FILE .FA>
reference_hap2: <LOCATION OF HAPLOTYPE ASSEBMLY FILE .FA>
reference_haplotigs: <LOCATION OF THE HAPLOTIGS FILE, REMOVED DURING CURATION .FA>

# If a mapped bam already exists use the below + --mapped TRUE on the nextflow command else ignore it and the pipeline will create it.
mapped_bam: <MAPPED BAM .BAM>

merquryfk:
  fastk_hist: <THE PATH TO THE .HIST FILE>
  fastk_ktab: <PATH TO THE DIRECTORY CONTAINING THE KTAB FILES, ENSURE THE HIDDEN FILES ARE HERE TOO>

# Used by both subpipelines
longread:
  type: <hifi|clr|ont|illumina>
  dir: <DIRECTORY OF LONGREAD FILES .FASTA.GZ>
curationpretext:
  aligner: <minimap2|BWAMEM>
  telomere_motif: <TELOMERE MOTIF OF SAMPLE>
  hic_dir: <DIRECTORY OF HIC READ FILES .CRAM AND .CRAI>
btk:
  taxid: 1464561
  lineages: < CSV LIST OF DATABASES TO USE: "insecta_odb10,diptera_odb10">
  gca_accession: GCA_0001 <DEFAULT, DO NOT CHANGE UNLESS YOU HAVE A GCA_ACCESSION FOR YOUR SPECIES >

  nt_database: <DIRECTORY CONTAINING BLAST DB>
  nt_database_prefix: <BLASTDB PREFIX>
  diamond_uniprot_database_path: <PATH TO reference_proteomes.dmnd FROM UNIPROT>
  diamond_nr_database_path: <PATH TO nr.dmnd>
  ncbi_taxonomy_path: <DIRECTORY CONTAINING THE TAXDUMP>
  ncbi_rankedlineage_path: <FOLDER CONTAINING THE rankedlineage.dmp FILE>
  config: <PATH TO ear/conf/sanger-tol-btk.config TO OVERWRITE PROCESS LIMITS>
```

Now, you can run the pipeline using:

```bash
nextflow run sanger-tol/ear -profile <singularity,docker> \\
   --input assets/idCulLati1.yaml \\
   --mapped TRUE \\ # OPTIONAL
   --steps ["", "btk", "cpretext", "merquryfk"] # OPTIONAL CSV LIST OF STEPS TO EXCLUDE FROM EXECUTION
   --outdir test
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Credits

sanger-tol/ear was originally written by DLBPointon.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use sanger-tol/ear for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
