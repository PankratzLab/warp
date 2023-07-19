version 1.0

struct PairedFastqs {
  File read1
  File read2
  String readgroup_format
  String flowcell_bam_basename
}

struct SampleAndPairedFastqs {
  String base_file_name
  String? final_gvcf_base_name
  Array[PairedFastqs] flowcell_paired_fastqs
  String sample_name
  String paired_fastqs_suffix
}

