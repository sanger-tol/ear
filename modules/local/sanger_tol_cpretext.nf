process SANGER_TOL_CPRETEXT {
    tag "$reference"
    label 'process_low'

    input:
    path(reference)
    path(longread_dir)
    path(cram_dir)
    path(config_file)

    output:
    tuple val(reference), path("*_out/*"),      emit: dataset
    path "versions.yml",                        emit: versions

    script:
    def pipeline_name                       =   "sanger-tol/curationpretext" // should be a task.ext.args
    def (pipeline_prefix,pipeline_suffix)   =   pipeline_name.split('/')
    def args                                =   task.ext.args               ?:  ""
    def executor                            =   task.ext.executor           ?:  ""
    def profiles                            =   task.ext.profiles           ?:  ""
    def get_version                         =   task.ext.version_data       ?:  "UNKNOWN - SETTING NOT SET"
    def config                              =   config_file                 ? "-c $config_file"         : ""
    def pipeline_version                    =   task.ext.version            ?: "draft_assemblies"

    // Seems to be an issue where a nested pipeline can't see the files in the same directory
    // Running realpath gets around this but the files copied into the folder are
    // now just wasted space. Should be fixed with using Mahesh's method of nesting but
    // this is proving a bit complicated with BTK

    // outdir should be an arg
    """
    $executor 'nextflow run $pipeline_name \\
        -r $pipeline_version \\
        -profile  $profiles \\
        --input "\$(realpath $reference)" \\
        --outdir ${reference}_${pipeline_suffix}_out \\
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
}
