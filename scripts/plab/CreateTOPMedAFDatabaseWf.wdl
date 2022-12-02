version 1.0
## This WDL invokes bcftools to concatenate and index a set of individual
## vcfs. The AncestrySpecificAlleleFrequency workflow that calculates and
## writes ancestry annotations into the individual chromosome vcfs is 
## executed separately for each chromosome to distribute processing over
## 23 separate compute nodes, then the results are gathered and indexed
## here.
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - input_vcfs : absolute path to vcfs of individual TOPMed chromosomes,
##      annotated with ancestry-specific allele frequencies using
##      AncestrySpecificAlleleFrequencyWf.wdl.
## - output_base_name : a name for the final output vcf+index files.
##
## Outputs :
## - A vcf+index with ancestry-specific allele frequencies for a reference genome. 
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##

# WORKFLOW DEFINITION
workflow CreateTOPMedAFDatabase {
  input {
    Array[File] input_vcfs
    String output_base_name

    String bcftools_docker = "us.gcr.io/broad-gotc-prod/imputation-bcf-vcf:1.0.5-1.10.2-0.1.16-1649948623"
  }

  String final_vcf_name = output_base_name + ".ancestry.af.vcf.gz"

  call GatherAndIndexTaggedVcfs {
    input:
      input_vcfs = input_vcfs,
      output_vcf_name = final_vcf_name,

      docker = bcftools_docker
  }

  # Outputs that will be retained when execution is complete
  output {
    File output_vcf = GatherAndIndexTaggedVcfs.output_vcf
    File output_vcf_index = GatherAndIndexTaggedVcfs.output_vcf_index
  }
}

# TASK DEFINITIONS
# Concatenate input vcfs into a single vcf and index in tbi format.
task GatherAndIndexTaggedVcfs {
  input {
    Array[File] input_vcfs
    String output_vcf_name
 
    String docker
  }
  
  command {
    bcftools concat ~{sep=' ' input_vcfs} -Oz -o "~{output_vcf_name}"
    bcftools index -t ~{output_vcf_name}
  }

  runtime {
    docker: docker
  }

  output {
    File output_vcf = "~{output_vcf_name}"
    File output_vcf_index = "~{output_vcf_name}.tbi"
  }
}
