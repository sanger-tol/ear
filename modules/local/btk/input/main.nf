process BTK_INPUT {
    executor 'local'

    input:
    tuple val(meta), val(reference)
    val blastp
    val blastn
    val blastx
    val tax_dump
    val busco_lineages
    val taxon
    val busco_config
    val btk_extra_opts

    output:
    path "btk_params_file.json", emit: json_params_file

    exec:
    def btk_inputs = btk_extra_opts + [
        'fasta': reference.toUriString(),
        'busco_lineages': busco_lineages,
        'taxon': taxon,
        'taxdump': tax_dump?.toUriString(),
        'blastp': blastp?.toUriString(),
        'blastn': blastn?.toUriString(),
        'blastx': blastx?.toUriString(),
    ].findAll { it.value } // filter out falsy values (null, false, "", [], etc)
    def jsonBuilder = new groovy.json.JsonBuilder(btk_inputs)
    file("${task.workDir}/btk_params_file.json").text = jsonBuilder.toPrettyString()
}
