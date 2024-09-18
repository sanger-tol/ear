process NCBIDATASETS_DOWNLOAD {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::ncbi-datasets-cli=15.11.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ncbi-datasets-pylib:15.11.0--pyhdfd78af_0':
        'staphb/ncbi-datasets:15.11.0' }"

    input:
    val(input_data)

    output:
    val(output_data)    , emit: taxonomy
    path "versions.yml" , emit: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def valid_commands = ["taxonomy", "taxon"]
    if (!valid_commands.contains(meta.command)) {
        error "Unsupported command: ${meta.command} "
    }

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id.replaceAll(' ', '_')}"

    """

    [ -e /usr/local/ssl/cacert.pem ] && export SSL_CERT_FILE=/usr/local/ssl/cacert.pem

    datasets summary \\
        ${meta.command} "${meta.latin_name}" ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-datasets-cli: \$(echo \$(datasets --version 2>&1) | sed 's/datasets version: //' )
    END_VERSIONS
    """

    stub:
    def args    = task.ext.args     ?: ''
    def prefix  = task.ext.prefix   ?: "${meta.id.replaceAll(' ', '_')}"
    """

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-datasets-cli: \$(echo \$(datasets --version 2>&1) | sed 's/datasets version: //' )
    END_VERSIONS
    """
}