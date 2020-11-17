nextflow.enable.dsl=2

process copy_file {
    publishDir "output"

    input:
    path(input_file)

    output:
    path(input_file_copy)

    script:
    input_file_copy = "${input_file}.copy.txt"
    """
    cp "${input_file}" "${input_file_copy}"
    """
}

workflow {
    files = Channel.from([
        'http://127.0.0.1:9000/bucket1/files/Run1/Project_1/Sample_ABC/ABC.txt',
        'http://127.0.0.1:9000/bucket1/files/Run2/Project_2/Sample_DEF/DEF.txt',
        'http://127.0.0.1:9000/bucket1/files/Run3/Project_3/Sample_GHI/GHI.txt'
        ])

    copy_file(files)
}
