version 1.0
## This WDL invokes the somalier tool (https://github.com/brentp/somalier) to evaluate relatedness
## among a cohort of individuals from a jointly-genotyped vcf. Note: somalier is not designed to produce
## reliable results from a single-sample vcf or gvcf; for single samples, use the bam file.
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - input_vcf : absolute path to a joint-genotyped vcf
## - input_vcf_index : absolute path to the corresponding index file. Note that somalier implicitly assumes
##	that index file is co-located with the vcf files. Note also that in order for Cromwell
##	to copy or link the index file into the container at execution time, it is necessary to 
##	explicitly pass the index file path into the ExtractSites task even though the value is not
##	passed to the somalier invocation..
## - sites_vcf: absolute path to a <sites>.vcf.gz file, which is a VCF of known polymorphic sites
## - ref_fasta: absolute path to a reference fasta file
## - pedigree: an optional but strongly recommended pedigree file from which to calculate or infer relateness
## - infer: true or false; infer first-degree relationships between samples based on pedigree; default = false
##	https://github.com/brentp/somalier/wiki/pedigree-inference. Note: do not try to infer relatedness
##      in consanguineous families without a pedigree file.
## - output_base_name: An optional base name for the relatedness output file set.
##
## Outputs :
## - A set of relatedness files.
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## For program versions, see docker containers. 
##

import "../../tasks/plab/SomalierTasks.wdl" as Somalier

# WORKFLOW DEFINITION
workflow SomalierRelateMultiSampleVcf {
  input {
    File input_vcf
    File input_vcf_index
    File sites_vcf
    File ref_fasta
    Boolean infer = false
    File? pedigree
    String output_base_name

    String somalier_docker = "brentp/somalier:v0.2.15"
  }

  File vcf_index = input_vcf_index

  # Extract sites.
  call Somalier.ExtractSitesMultiSampleVcf {
    input:
      input_vcf = input_vcf,
      input_vcf_index = input_vcf_index,
      sites_vcf = sites_vcf,
      ref_fasta = ref_fasta,
      output_file_name = output_base_name + ".somalier",

      docker = somalier_docker
  }

  call Somalier.Relate {
    input: 
      extracted_files = ExtractSitesMultiSampleVcf.output_files,
      pedigree = pedigree,
      infer = infer,
      output_base_name = output_base_name,

      docker = somalier_docker
  }

  # Outputs that will be retained when execution is complete
  output {
    File result_html = Relate.result_html
    File? result_groups = Relate.result_groups
    File result_pairs = Relate.result_pairs
    File result_samples = Relate.result_samples
  }
}

