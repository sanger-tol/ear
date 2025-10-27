process CPRETEXT_INPUT {
    executor 'local'

    input:
    tuple val(meta), val(reference)
    val longread_dir
    val cram_dir
    val telomere_motif
    val aligner
    val cpretext_extra_opts

    output:
    path "cpretext_params_file.json", emit: json_params_file

    exec:
    def cpretext_inputs = cpretext_extra_opts + [
        'sample': meta.id,
        'reads': longread_dir.toUriString(),
        'cram': cram_dir.toUriString(),
        'teloseq': telomere_motif,
        'aligner': aligner,
    ].findAll { it.value } // filter out falsy values (null, false, "", [], etc)
    def jsonBuilder = new groovy.json.JsonBuilder(cpretext_inputs)
    file("${task.workDir}/cpretext_params_file.json").text = jsonBuilder.toPrettyString()
}
