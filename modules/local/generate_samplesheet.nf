process GENERATE_SAMPLESHEET {
    tag "$meta.id"
    label "process_low"

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
    'docker.io/ubuntu:20.04' }"

    input:
    tuple val(meta), path(reference)
    path(pacbio_path)
    val(reads_layout)

    output:
    tuple val(meta),    path("samplesheet.csv"),    emit: csv
    path "versions.yml",                            emit: versions

    script:
    def args    = task.ext.args     ?: ""
    """
    echo "Debug: Contents of ${pacbio_path}"
    ls -l ${pacbio_path}

    echo "sample,datatype,datafile,library_layout" > pre_samplesheet.csv

    for file in ${pacbio_path}/*.fasta.gz; do
        echo "Debug: Processing file \$file"
        echo "${meta.id},pacbio,\$file,\$reads_layout" >> pre_samplesheet.csv
    done

    echo "Debug: MOVE pre_samplesheet.csv to samplesheet.csv"

    mv pre_samplesheet.csv samplesheet.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        generate_samplesheet: \$(generate_samplesheet.py -v)
    END_VERSIONS
    """

    stub:
    """
    touch samplesheet.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        generate_samplesheet: \$(generate_samplesheet.py -v)
    END_VERSIONS
    """
}
