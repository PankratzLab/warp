version 1.0
## This WDL invokes bcftools to calculate ancestry-specific allele frequencies for a
## a single-chromosome bcf+index based on a file of ancestry notations. Final bcfs
## from this workflow can be concatenated into a single reference file.
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following:
## - input_bcf : absolute path to a bcf file.
## - input_bcf_index : absolute path to the corresponding bcf.csi index file.
## - interval_file : a file defining intervals over which to split the bcf for parallel processing.
## - ancestries : a text file of ancestry designations values from a reference genome.
## - info_tags : the INFO tags to be filled in
## - output_base_name : base name for output files.
##
## Outputs :
## - A compressed, unindexed bcf tagged with ancestry-specific allele frequencies.
##
## Cromwell version support
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation.
## For program versions, see docker containers.
##

# WORKFLOW DEFINITION
workflow AncestrySpecificAlleleFrequency {
  input {
    File input_bcf
    File input_bcf_index
    File interval_file
    File ancestries
    String info_tags
    String output_base_name

    String bcftools_docker = "staphb/bcftools:1.11"
  }

  Array[String] intervals = read_lines(interval_file)

  scatter (idx in range(length(intervals)) ) {
    call CalculateAncestrySpecificTagsForRegion {
      input: 
        input_bcf = input_bcf,
        input_bcf_index = input_bcf_index,
        region = intervals[idx], 
        ancestries = ancestries,
        info_tags = info_tags,
        output_file_name = output_base_name + "." + idx + ".vcf.gz",

        docker = bcftools_docker
    }
  }

  call AssembleVcf {
    input:
      region_vcfs = CalculateAncestrySpecificTagsForRegion.output_vcf,
      output_file_name = output_base_name + ".af.vcf.gz",

      docker = bcftools_docker
  }

  output {
#    Array[File] region_vcfs = CalculateAncestrySpecificTagsForRegion.output_vcf
    File output_vcf = AssembleVcf.output_vcf
  }
}

## TASK DEFINITIONS
# Split the bcf into several files by region; the number of files is determined by the
# number of regions defined in the interval_list input file, which must be in the form
# chr20:1-200000. Then stream to +fill-tags plugin to compute and set ancestry-specific
# allele frequency tags specified by info_tags.

task CalculateAncestrySpecificTagsForRegion {
  input{
    File input_bcf
    File input_bcf_index
    String region
    File ancestries
    String info_tags 
    String output_file_name

    String docker
  }

  File bcf_index = input_bcf_index
   
  command {
    bcftools view -r ~{region} ~{input_bcf} -Ou | bcftools +fill-tags -Ou -- -S ~{ancestries} -t ~{info_tags} | bcftools view -G -Oz -o "~{output_file_name}"
  }

  runtime {
    docker: docker
  }

  output {
    File output_vcf = "~{output_file_name}"

  }   
}

# Aggregate the split regions back into a single file.
task AssembleVcf {
  input {
    String output_file_name
    Array[File] region_vcfs

    String docker
  }

  command {
    # We can naively concatenate these files because they were just split from the same input file.
    bcftools concat -n ~{sep=' ' region_vcfs} -Oz -o "~{output_file_name}"
  } 

  runtime {
    docker: docker
  }
 
  output {
    File output_vcf = "~{output_file_name}"

  }
}
