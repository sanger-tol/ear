# sanger-tol/ear: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Naming based on: [Mythical creatures](https://en.wikipedia.org/wiki/List_of_legendary_creatures_by_type).

## v1.0.0 - Aquatic Bahamut [21/08/2024]

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

|

\* for pipelines, please check their own CHANGELOG file for a full list of software dependencies.

### Dependencies

The pipeline depends on a number of databases which are noted in [README](README.md) and [USAGE](docs/usage.md).
