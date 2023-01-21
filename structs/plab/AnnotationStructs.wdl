version 1.0

struct VcfAndIndex {
  File input_vcf
  File input_vcf_index
  String output_base_name
}

struct VepPluginDataSource {
  File data
  File index
}

struct VepPlugin {
  String short_name
  Array[VepPluginDataSource] data_sources
}
