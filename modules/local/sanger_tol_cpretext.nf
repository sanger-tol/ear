process SANGER_TOL_CPRETEXT {
    tag "$reference"
    label 'process_low'

    input:
    path(reference)
    path(longread_dir)
    path(cram_dir)
    path(config_file)

    output:
    tuple val(reference), path("*_out/*"),  emit: dataset
    path "versions.yml",                    emit: versions

    script:
    def pipeline_name                       =   task.ext.pipeline_name
    def (pipeline_prefix,pipeline_suffix)   =   pipeline_name.split('/')
    def output_dir                          =   "${reference}_${pipeline_suffix}_out"
    def args                                =   task.ext.args               ?:  ""
    def executor                            =   task.ext.executor           ?:  ""
    def profiles                            =   task.ext.profiles           ?:  ""
    def get_version                         =   task.ext.version_data       ?:  "UNKNOWN - SETTING NOT SET"
    def config                              =   config_file                 ? "-c $config_file"         : ""
    def pipeline_version                    =   task.ext.version            ?: "main"

    // Seems to be an issue where a nested pipeline can't see the files in the same directory
    // Running realpath gets around this but the files copied into the folder are
    // now just wasted space. Should be fixed with using Mahesh's method of nesting but
    // this is proving a bit complicated with BTK

    // Running these as unique jobs means we don't have to worry about multiple pipeline
    // head jobs running in the same initial Nextflow head, this balloons memory
    // for LSF we can use -Is -tty to keep the output of this sub-pipeline in
    // terminal, keeping the job open until the pipeline completes

    // the printf statement appends the subpipelines versions file to the main versions file
    """
    $executor 'nextflow run $pipeline_name \\
        -r $pipeline_version \\
        -profile  $profiles \\
        --input "\$(realpath $reference)" \\
        --outdir $output_dir \\
        --longread "\$(realpath $longread_dir)" \\
        --cram "\$(realpath $cram_dir)" \\
        $args \\
        $config \\
        -resume'
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        $pipeline_suffix: $pipeline_version
        Nextflow: \$(nextflow -v | cut -d " " -f3)
        executor system: $get_version
    END_VERSIONS
    """

    // INFILE=${output_dir}/pipeline_info/software_versions.yml
    // IFS=\$'\n'
    // echo "$pipeline_name:" >> versions.yml
    // for LINE in \$(cat "\$INFILE")
    // do
    //     echo "  \$LINE" >> versions.yml
    // done

    stub:
    def pipeline_version                    =   task.ext.version        ?: "main"
    def (pipeline_prefix,pipeline_suffix)   =   pipeline_name.split('/')
    def output_dir                          =   "${reference}_${pipeline_suffix}_out"
    """
    mkdir ${output_dir}
    touch ${output_dir}/reference.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        $pipeline_suffix: $pipeline_version
        Nextflow: \$(nextflow -v | cut -d " " -f3)
        executor system: $get_version
    END_VERSIONS
    """
}
