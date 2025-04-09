# sanger-tol/ear: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Naming based on: [Audiologists](https://en.wikipedia.org/wiki/Category:Audiologists).

## v0.7.0 - Raymond Carhart [08/03/2025]

- Removing the mapping subworkflow as it is no longer needed.
  - This was a requirement before BLOBTOOLKIT implemented its own mapping subworkflow.
  - This significantly speeds up the pipeline in two ways.
    - We no longer have to wait for mapping to complete before BTK.
    - BTK doesn't have to struggle with the much larger mapped bam that was being created (cpretext was creating a bam with lots of suplementary data).
  - Removed all input parsing for the mapping.
- NF-TEST implementation.
  - We have implemented an output file sanity check rather than rely solely on pipeline completion.
- curationpretext has been updated to [1.3.1 - UNSC Pillar-of-Autumn](https://github.com/sanger-tol/curationpretext/releases/tag/1.3.1)
  - Update the curationpretext module so that it takes all available cpretext params.
- blobtoolkit has been updated to [0.7.1 - Psyduck Patch 1](https://github.com/sanger-tol/blobtoolkit/releases/tag/0.7.1)
- Removed `-resume` from nested pipelines as it isn't particularly useful, resuming the main pipeline will re-start those processes rather than resume them.
- Deleting out of date files (btk_draft.yaml)
- Adding new config file (./assets/blobtoolkit.config) which should overwrite the BLASTN config in the modules.config of blobtoolkit.
  - This implements the `-dust no` flag rather than allowing for 'medium' use of dust. There is also a selection of args to use for BLOBTOOLS_CHUNK in the case of high dupe genomes.
  - blobtoolkit's module has been updated to take the reads_dir as the samplesheet no longer contains an absolute path to files.
- Removed the GENERATE_SAMLESHEET script as we can do the same in bash, there's no point in using a python if we don't need to.
  - The container has also been updated to Ubuntu 20.04 as we don't need Python anymore.
- Update the use of values in yaml_input.
- GFASTATS has been updated to version 1.3.10.
- NF-Core template subworkflows are not properly in use for initialisation of the pipeline and the initial setting of the channels.

### Software dependencies

| Dependency                   | Old version                | New version                           |
| ---------------------------- | -------------------------- | ------------------------------------- |
| sanger-tol/curationpretext\* | 1.1.0 (UNSC Delphi)        | 1.2.0 (UNSC Spirit-of-Fire)           |
| sanger-tol/blobtoolkit\*     | 0.6.0 (Bellsprout)         | 0.7.0 (Psyduck)                       |
| MINIMAP2_ALIGN               | 2.28                       | REMOVED                               |
| SAMTOOLS_MERGE               | 1.20--h50ea8bc_0           | REMOVED                               |
| SAMTOOLS_SORT                | 1.21--h50ea8bc_0           | REMOVED                               |
| GENERATE_SAMPLESHEET         | Python 3.9, v1.0.0         | coreutils=9.1, v1.1.0                 |
| GFASTATS                     | 1.3.6                      | 1.3.10                                |
| MERQURYFK                    | FK=1.0.1, MFK=1.1.0, R=4.2 | FK=1.1.0 MFK=pre-release 1.2.0 R=4.42 |

### Parameters

| Old parameter | New parameter |
| ------------- | ------------- |
| --mapped      |               |

### KNOWN BUG

- BLOBTOOLKIT relies on BUSCO 5.5, which does NOT run with single line fasta!
  - This needs to be folded, use `seqkit seq -l 70`

## v0.6.2 - Robert Beiny H2 [09/01/2025]

- Modules have been updated to remove conda defaults.

### Software dependencies

| Dependency                   | Old version         | New version         |
| ---------------------------- | ------------------- | ------------------- |
| sanger-tol/blobtoolkit\*     |                     | 0.6.0 (Bellsprout)  |
| sanger-tol/curationpretext\* | 1.0.0 (UNSC Cradle) | 1.1.0 (UNSC Delphi) |
| GFASTATS                     |                     | 1.3.6--hdcf5f25_3   |
| MERQUERY_FK                  |                     | 1.2                 |
| MINIMAP2_ALIGN               |                     | 2.28                |
| SAMTOOLS_MERGE               | 1.20--h50ea8bc_0    | 1.21--h50ea8bc_0    |
| SAMTOOLS_SORT                | 1.21--h50ea8bc_0    | 1.21--h50ea8bc_0    |

## v0.6.1 - Robert Beiny H1 [08/10/2024]

- Blobtookit version was specified in the wrong location, so defaulted to a development branch "draft_assemblies", this has now been updated to v0.6.0.
- Zenodo DOI has now been added to the repo.

## v0.6.0 - Robert Beiny [20/09/2024]

Initial release of sanger-tol/ear, created with the [nf-core](https://nf-co.re/) template.
The current pipeline means the MVP for ear.

### Added

GFASTATS to generate statistics on the input primary genome.
MERQURY_FK to generate kmer graphs and analyses of the primary, haplotype and merged assembly.
MAIN_MAPPING which is a small mapping subworkflow, that can work with single and paired reads.
BLOBTOOLKIT to generate busco files and blobtoolkit dataset/plots.
CURATIONPRETEXT to generate pretext plots and pngs.

### Parameters

| Old parameter | New parameter |
| ------------- | ------------- |
|               | --mapped      |
|               | --steps       |

### Software dependencies

| Dependency                   | Old version | New version         |
| ---------------------------- | ----------- | ------------------- |
| sanger-tol/blobtoolkit\*     |             | 0.6.0 (Bellsprout)  |
| sanger-tol/curationpretext\* |             | 1.0.0 (UNSC Cradle) |
| GFASTATS                     |             | 1.3.6--hdcf5f25_3   |
| MERQUERY_FK                  |             | 1.2                 |
| MINIMAP2_ALIGN               |             | 2.28                |
| SAMTOOLS_MERGE               |             | 1.20--h50ea8bc_0    |
| SAMTOOLS_SORT                |             | 1.20--h50ea8bc_0    |

\* for pipelines, please check their own CHANGELOG file for a full list of software dependencies.

### Dependencies

The pipeline depends on a number of databases which are noted in [README](README.md) and [USAGE](docs/usage.md).
