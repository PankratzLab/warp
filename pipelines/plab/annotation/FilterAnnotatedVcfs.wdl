version 1.0
## This WDL invokes VEP's filter_vep tool to filter a vcf
## produced by the AnnotateVcfs workflow. If the input is
## an array of shard vcfs, VepFilterVcf will concatenate them
## to a single file before filtering. Filters are specified
## as an array of strings in the input JSON. See
## https://uswest.ensembl.org/info/docs/tools/vep/script/vep_filter.html
## for instructions on constructing filters.
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - input_vcfs : an array of absolute path(s) to one or more vcfs.
##                Multiple vcfs will be concatenated before filtering,
## 		  so be sure that makes sense to do.
## - filters : an array of filter strings in filter_vep format
## - output_base_name : a name for the tab-delimited output file (no file extension).
## - filter_description : an optional string to be appended to the 
##      output_base_name that characterizes the filtering applied;
##      default = "".
##
## Outputs :
## - A tab-delimited text file of data matching all filters. 
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##

import "../../../tasks/plab/AnnotationTasks.wdl" as Annotate

# WORKFLOW DEFINITION
workflow FilterAnnotatedVcfs {
  input {
    Array[File]+ input_vcfs
    Array[String] filters
    String output_base_name
    String filter_description = ""
  }

  Boolean gather = length(input_vcfs) > 1
  if( gather ) {
      String output_file_name = output_base_name + ".vcf.gz"
    
      call Annotate.GatherAndIndexVcfs {
        input: 
          input_vcfs = input_vcfs,
          output_vcf_name = output_file_name
      }
  }

  File input_vcf =  select_first([GatherAndIndexVcfs.output_vcf, input_vcfs[0]])
  call Annotate.VepFilterVcf {
    input:
      input_vcf = input_vcf,
      filters = filters,
      output_base_name = output_base_name,
      filter_description = filter_description
  }
  # Outputs that will be retained when execution is complete
  output {
    File output_file = VepFilterVcf.output_vcf
  }
}

