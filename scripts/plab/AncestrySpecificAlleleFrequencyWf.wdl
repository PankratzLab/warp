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
    String output_file_name = output_base_name + "." + idx + ".vcf.gz"
    
    call CalculateAncestrySpecificTagsForRegion {
      input: 
        input_bcf = input_bcf,
        input_bcf_index = input_bcf_index,
        region = intervals[idx], 
        ancestries = ancestries,
        info_tags = info_tags,
        output_file_name = output_file_name,

        docker = bcftools_docker
    }
    
    call IndexShard {
      input:
        input_vcf = CalculateAncestrySpecificTagsForRegion.output.vcf,
        output_file_name = output_file_name,
        
        docker = bcftools_docker
    }
  }

  call AssembleVcf {
    input:
      region_vcfs = CalculateAncestrySpecificTagsForRegion.output_vcf,
      region_vcf_indices = IndexShard.output_vcf_index,
      output_file_name = output_base_name + ".af.vcf.gz",

      docker = bcftools_docker
  }

  output {
#    Array[File] region_vcfs = CalculateAncestrySpecificTagsForRegion.output_vcf
#    Array[File] region_vcf_indices = IndexShard.output_vcf_index
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
    bcftools index -t ~{output_file_name}
  }

  runtime {
    docker: docker
  }

  output {
    File output_vcf = "~{output_file_name}"
    File output_vcf_index = "~{output_file_name}.tbi"
  }   
}
# Index shards so that concat can remove duplicates
task IndexShard {
  input{
    File input_vcf
    String output_file_name
    
    String docker
  }
    
  command {
    bcftools index -t ~{input_vcf}
  }

  runtime {
    docker: docker
  }

  output {
    File output_vcf_index = "~{output_file_name}.tbi"
  } 
    
}
# Aggregate the split regions back into a single file.
task AssembleVcf {
  input {
    String output_file_name
    Array[File] region_vcfs
    Array[File] region_vcf_indices
    
    String docker
  }
  Array[File] index_files = region_vcf_indices
  
  command {
    bcftools concat -a -D ~{sep=' ' region_vcfs} -Oz -o "~{output_file_name}"
  } 

  runtime {
    docker: docker
  }
 
  output {
    File output_vcf = "~{output_file_name}"
  }
}
