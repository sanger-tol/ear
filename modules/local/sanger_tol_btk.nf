process SANGER_TOL_BTK {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(reference, stageAs: "REFERENCE.fa")
    tuple val(meta2), path(samplesheet_csv, stageAs: "SAMPLESHEET.csv")
    path blastp, stageAs: "blastp.dmnd"
    path blastn
    path blastx
    path tax_dump
    val busco_lineages
    val taxon
    val gca_accession

    output:
    tuple val(meta), path("*_out/blobtoolkit/REFERENCE"),           emit: dataset
    path "*_out/blobtoolkit/plots" ,                                emit: plots
    path "*_out/blobtoolkit/REFERENCE/summary.json.gz",             emit: summary_json
    path "*_out/busco",                                             emit: busco_data
    path "*_out/multiqc",                                           emit: multiqc_report
    path "*_out/pipeline_info/blobtoolkit",                         emit: pipeline_info
    path "*out/pipeline_info/blobtoolkit/software_versions.yml",    emit: versions

    script:
    def pipeline_name                       =   task.ext.pipeline_name
    def (pipeline_prefix,pipeline_suffix)   =   pipeline_name.split('/')
    def output_dir                          =   "${meta.id}_${pipeline_suffix}_out"
    def args                                =   task.ext.args           ?:  ""
    def executor                            =   task.ext.executor       ?:  ""
    def profiles                            =   task.ext.profiles       ?:  ""
    def get_version                         =   task.ext.version_data   ?:  "UNKNOWN - SETTING NOT SET"
    def pipeline_version                    =   task.ext.version        ?: "main"

    // Seems to be an issue where a nested pipeline can't see the files in the same directory
    // Running realpath gets around this but the files copied into the folder are
    // now just wasted space. Should be fixed with using Mahesh's method of nesting but
    // this is proving a bit complicated with BTK

    // blastx and blastp can use the same database hence the StageAs

    // Running these as unique jobs means we don't have to worry about multiple pipeline
    // head jobs running in the same initial Nextflow head, this balloons memory
    // for LSF we can use -Is -tty to keep the output of this sub-pipeline in
    // terminal, keeping the job open until the pipeline completes

    // the printf statement appends the subpipelines versions file to the main versions file
    """
    $executor 'nextflow run $pipeline_name \\
        -r $pipeline_version \\
        -profile  $profiles \\
        --input "\$(realpath $samplesheet_csv)" \\
        --outdir ${meta.id}_btk_out \\
        --fasta ./REFERENCE.fa \\
        --busco_lineages $busco_lineages \\
        --taxon $taxon \\
        --taxdump "\$(realpath $tax_dump)" \\
        --blastp "\$(realpath blastp.dmnd)" \\
        --blastn "\$(realpath $blastn)" \\
        --blastx "\$(realpath $blastx)" \\
        --use_work_dir_as_temp true \\
        $config \\
        $args \\
        -resume'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Blobtoolkit: $pipeline_version
        Nextflow: \$(nextflow -v | cut -d " " -f3)
        executor system: $get_version
    END_VERSIONS
    """

    // INFILE=${output_dir}/pipeline_info/software_versions.yml
    // IFS=\$'\n'
    // echo "$pipeline_name:" >> versions.yml
    // for \${LINE} in \$(cat "\$INFILE")
    // do
    //     echo "  \${LINE}" >> versions.yml
    // done

    stub:
    def pipeline_version    =   task.ext.version        ?: "main"

    """
    mkdir -p ${meta.id}_btk_out/blobtoolkit/${meta.id}_out
    touch ${meta.id}_btk_out/blobtoolkit/${meta.id}_out/test.json.gz

    mkdir ${meta.id}_btk_out/blobtoolkit/plots
    touch ${meta.id}_btk_out/blobtoolkit/plots/test.png

    mkdir ${meta.id}_btk_out/busco
    touch ${meta.id}_btk_out/busco/test.batch_summary.txt
    touch ${meta.id}_btk_out/busco/test.fasta.txt
    touch ${meta.id}_btk_out/busco/test.json

    mkdir ${meta.id}_btk_out/multiqc
    mkdir ${meta.id}_btk_out/multiqc/multiqc_data
    mkdir ${meta.id}_btk_out/multiqc/multiqc_plots
    touch ${meta.id}_btk_out/multiqc/multiqc_report.html

    mv ${meta.id}_btk_out/pipeline_info blobtoolkit_pipeline_info

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Blobtoolkit: $pipeline_version
        Nextflow: \$(nextflow -v | cut -d " " -f3)
        executor system: $get_version
    END_VERSIONS
    """
}
