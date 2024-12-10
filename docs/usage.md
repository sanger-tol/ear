# sanger-tol/ear: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

<!-- TODO nf-core: Add documentation about anything specific to running your pipeline. For general topics, please point to (and add to) the main nf-core website. -->

## Yaml input

You will need to create a yaml with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location.

```bash
--input '[path to samplesheet file]'
```

The structure of this file should be as follows:

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
  lineages: <CSV LIST OF DATABASES TO USE: "insecta_odb10,diptera_odb10">
  gca_accession: GCA_0001 <DEFAULT, DO NOT CHANGE UNLESS YOU HAVE A GCA_ACCESSION FOR YOUR SPECIES>
  nt_database: <DIRECTORY CONTAINING BLAST DB>
  nt_database_prefix: <BLASTDB PREFIX>
  diamond_uniprot_database_path: <PATH TO reference_proteomes.dmnd FROM UNIPROT>
  diamond_nr_database_path: <PATH TO nr.dmnd>
  ncbi_taxonomy_path: <DIRECTORY CONTAINING THE TAXDUMP>
  ncbi_rankedlineage_path: <FOLDER CONTAINING THE rankedlineage.dmp FILE>
  config: <PATH TO ear/conf/sanger-tol-btk.config TO OVERWRITE PROCESS LIMITS>
```

## Database download and setup (Taken from sanger-tol/blobtoolkit)

The BlobToolKit pipeline can be run in many different ways. The default way requires access to several databases:

1. [NCBI taxdump database](https://www.ncbi.nlm.nih.gov/taxonomy)
2. [NCBI nucleotide BLAST database](https://blast.ncbi.nlm.nih.gov/doc/blast-help/downloadblastdata.html#databases)
3. [UniProt reference proteomes database](https://www.uniprot.org)
4. [BUSCO database](https://busco.ezlab.org)

It is a good idea to put a date suffix for each database location so you know at a glance whether you are using the latest version. We are using the `YYYY_MM` format as we do not expect the databases to be updated more frequently than once a month. However, feel free to use `DATE=YYYY_MM_DD` or a different format if you prefer.

### 1. NCBI taxdump database

Create the database directory and move into the directory:

```bash
DATE=2023_03
TAXDUMP=/path/to/databases/taxdump_${DATE}
mkdir -p $TAXDUMP
cd $TAXDUMP
```

Retrieve and decompress the NCBI taxdump:

```bash
curl -L ftp://ftp.ncbi.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz | tar xzf -
```

### 2. NCBI nucleotide BLAST database

Create the database directory and move into the directory:

```bash
DATE=2023_03
NT=/path/to/databases/nt_${DATE}
mkdir -p $NT
cd $NT
```

Retrieve the NCBI blast nt database (version 5) files and tar gunzip them. We are using the `&&` syntax to ensure that each command completes without error before the next one is run:

```bash
wget "ftp://ftp.ncbi.nlm.nih.gov/blast/db/v5/nt.???.tar.gz" -P $NT/ &&
for file in $NT/*.tar.gz; do
    tar xf $file -C $NT && rm $file;
done
```

### 3. UniProt reference proteomes database

You need [diamond blast](https://github.com/bbuchfink/diamond) installed for this step. The easiest way is probably using [conda](https://anaconda.org/bioconda/diamond). Make sure you have the latest version of Diamond (>2.x.x) otherwise the `--taxonnames` argument may not work.

Create the database directory and move into the directory:

```bash
DATE=2023_03
UNIPROT=/path/to/databases/uniprot_${DATE}
mkdir -p $UNIPROT
cd $UNIPROT
```

The UniProt `Refseq_Proteomes_YYYY_MM.tar.gz` file is very large (>160 GB) and will take a long time to download. The command below looks complex because it needs to get around the problem of using wildcards with wget and curl.

```bash
wget -q -O $UNIPROT/reference_proteomes.tar.gz \
  ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/$(curl \
    -vs ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/ 2>&1 | \
    awk '/tar.gz/ {print $9}')
tar xf reference_proteomes.tar.gz

# Create a single fasta file with all the fasta files from each subdirectory:
touch reference_proteomes.fasta.gz
find . -mindepth 2 | grep "fasta.gz" | grep -v 'DNA' | grep -v 'additional' | xargs cat >> reference_proteomes.fasta.gz

# create the accession-to-taxid map for all reference proteome sequences:
printf "accession\taccession.version\ttaxid\tgi\n" > reference_proteomes.taxid_map
zcat */*/*.idmapping.gz | grep "NCBI_TaxID" | awk '{print $1 "\t" $1 "\t" $3 "\t" 0}' >> reference_proteomes.taxid_map

# create the taxon aware diamond blast database
diamond makedb -p 16 --in reference_proteomes.fasta.gz --taxonmap reference_proteomes.taxid_map --taxonnodes $TAXDUMP/nodes.dmp --taxonnames $TAXDUMP/names.dmp -d reference_proteomes.dmnd
```

### 4. BUSCO databases

Create the database directory and move into the directory:

```bash
DATE=2023_03
BUSCO=/path/to/databases/busco_${DATE}
mkdir -p $BUSCO
cd $BUSCO
```

Download BUSCO data and lineages to allow BUSCO to run in offline mode:

```bash
wget -r -nH https://busco-data.ezlab.org/v5/data/
# the trailing slash after data is important. Otherwise wget doesn't get the subdirectories

# tar gunzip all folders that have been stored as tar.gz, in the same parent directories as where they were stored:
find v5/data -name "*.tar.gz" | while read -r TAR; do tar -C `dirname $TAR` -xzf $TAR; done
```

If you have [GNU parallel](https://www.gnu.org/software/parallel/) installed, you can also use the command below which will run faster as it will run the decompression commands in parallel:

```bash
find v5/data -name "*.tar.gz" | parallel "cd {//}; tar -xzf {/}"
```

## Blobtoolkit - YAML File and Nextflow configuration

As in the Snakemake version [a YAML configuration file](https://github.com/blobtoolkit/blobtoolkit/tree/main/src/blobtoolkit-pipeline/src#configuration) is needed to generate metadata summary. This YAML config file can be generated with a genome accession value for released assemblies (for example, GCA_XXXXXXXXX.X) or can be passed for draft assemblies (for example, [GCA_922984935.2.yaml](assets/test/GCA_922984935.2.yaml) using the `--yaml` parameter. Even for draft assemblies, a placeholder value should be passed with the `--accession` parameter.

The data in the YAML is currently ignored in the Nextflow pipeline version. The YAML file is retained only to allow compatibility with the BlobDir dataset generated by the [Snakemake version](https://github.com/blobtoolkit/blobtoolkit/tree/main/src/blobtoolkit-pipeline/src). The taxonomic information in the YAML file can be obtained from [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/data-hub/taxonomy/).

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run sanger-tol/ear --input assets/test.yaml --outdir ./results  -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

> Please note that conda is not supported for all tools in use for this pipeline, this limits use to docker or singularity

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

:::warning
Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).
:::

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull sanger-tol/ear
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [sanger-tol/ear releases page](https://github.com/sanger-tol/ear/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

:::tip
If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.
:::

## Core Nextflow arguments

:::note
These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).
:::

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

:::info
We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.
:::

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Azure Resource Requests

To be used with the `azurebatch` profile by specifying the `-profile azurebatch`.
We recommend providing a compute `params.vm_type` of `Standard_D16_v3` VMs by default but these options can be changed if required.

Note that the choice of VM size depends on your quota and the overall workload during the analysis.
For a thorough list, please refer the [Azure Sizes for virtual machines in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
