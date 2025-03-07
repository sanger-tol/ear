# sanger-tol/ear: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Naming based on: [Audiologists](https://en.wikipedia.org/wiki/Category:Audiologists).

## v0.7.0 - Raymond Carhart [08/03/2025]

- Removing the mapping subworkflow as it is no longer needed.
  - This was a requirement before BLOBTOOLKIT implemented it's own mapping subworkflow.
  - This significantly speeds up the pipeline in two ways.
    - We no longer have to wait for mapping to complete prior to BTK.
    - BTK doesn't have to struggle with the much larger mapped bam that was being created.
  - Removed all input parsing for the mapping.
- NF-TEST implementation.
  - We have implemented an output file sanity check rather than rely soley on pipeline completion.
- curationpretext has been updated to [1.2.0 - UNSC Spirit-of-Fire](https://github.com/sanger-tol/curationpretext/releases/tag/1.2.0)
  - Update the curationpretext module so that it takes all give cpretext values.
- removed `-resume` from nested pipelines as it isn't particularly useful seeing as resuming the main pipeline will re-start those processes rather than resume them.
- Deleting out of date files (btk_draft.yaml)
- Adding new config file (./assets/blobtoolkit.config) which should overwrite the BLASTN config in the modules.config
- Removed the GENERATE_SAMLESHEET script as we can do the same in bash
  - The container has also been updated to ubuntu 20.04 as we don't been python anymore.
- blobtoolkit's module has been updated to take the config file and reads_dir as the samplesheet no longer contains an absolute path to files.
- Update the use of values in yaml_input.


### Software dependencies

| Dependency                   | Old version         | New version                 |
| ---------------------------- | ------------------- | --------------------------- |
| sanger-tol/curationpretext\* | 1.1.0 (UNSC Delphi) | 1.2.0 (UNSC Spirit-of-Fire) |

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
