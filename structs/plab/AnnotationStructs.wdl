version 1.0

struct VcfAndIndex {
  File input_vcf
  File input_vcf_index
  String output_base_name
}

struct VepPlugin {
  String name
  String version_string
  Array[File] data_sources
  Array[File]? index_files
}
