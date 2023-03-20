version 1.0
## This WDL invokes GATK's CalculateGenotypePosteriors tool to
## calculated genotype posterior probabilities, reported as 
## updated values for GQ, based on a callset such as TOPMed,
## 1000Genomes, etc. 
##
## Current implementation allows a single callset vcf.
## Pedigree-based PP is not currently implemented.
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - vcf_units : array of dictionaries of vcf+index absolute file paths.
## - callsets_vcf : absolute path to supporting callset vcf.gz file.
## - callsets_vcf_index : absolute path to matching callset vcf index file.
##
## Outputs :
## - A filtered vcf+index per input vcf. 
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##

#import "../../structs/plab/AnnotationStructs.wdl"
import "/home/pankrat2/public/bin/gatk4/warp/structs/plab/AnnotationStructs.wdl"

# WORKFLOW DEFINITION
workflow CalculateGenotypePP {
  input {
    Array[VcfAndIndex] vcf_units
    File callsets_vcf
    File callsets_vcf_index

    String gatk_docker = "us.gcr.io/broad-gatk/gatk:4.2.6.1"
  }

    scatter ( unit in vcf_units ) {
      String output_file_name = unit.output_base_name + "CGP.vcf.gz"
    
      call CalcPosteriorProbabilities {
        input: 
          input_vcf = unit.input_vcf,
          input_vcf_index = unit.input_vcf_index,
          callsets_vcf = callsets_vcf,
  	  callsets_vcf_index = callsets_vcf_index, 
          output_vcf_name = output_file_name,

          docker = gatk_docker
      }
  }

  # Outputs that will be retained when execution is complete
  output {
    Array[File] output_vcf = CalcPosteriorProbabilities.output_vcf
    Array[File] output_vcf_index = CalcPosteriorProbabilities.output_vcf_index
  }
}

# TASK DEFINITIONS
# Calculate genotype posterior probabilities based on the provided
# supporting callset.
task CalcPosteriorProbabilities {
  input {
    File input_vcf
    File input_vcf_index
    File callsets_vcf
    File callsets_vcf_index
    String output_vcf_name
 
    String docker
  }
  
  File vcf_index = input_vcf_index
  File callset_index = callsets_vcf_index
 
 command <<<
	gatk --java-options "-Xms3000m -Xmx3250m -DGATK_STACKTRACE_ON_USER_EXCEPTION=true" \
	CalculateGenotypePosteriors \
	-V ~{input_vcf} \
	--supporting-callsets ~{callsets_vcf} \
	--create-output-variant-index true \
	-O "~{output_vcf_name}"
  >>>

  runtime {
    docker: docker
  }

  output {
    File output_vcf = "~{output_vcf_name}"
    File output_vcf_index = "~{output_vcf_name}.tbi"
  }
}
