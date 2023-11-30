version 1.0
## This WDL invokes the somalier tool (https://github.com/brentp/somalier) to evaluate relatedness
## among a set of BAM files. Note: somalier is not intended to process a single-sample vcf or gvcf.
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - sample_bam_units : An array of dictionaries, each containing the sample  name, absolute path to
##	a bam file, and absolute path to the bam index file. Note that somalier implicitly assumes
##	that the index files are co-located with the bam files. Note also that in order for Cromwell
##	to copy or link the index files into the container at execution time, it is necessary to 
##	explicitly pass the index file paths into the ExtractSites task even though the value is not
##	passed to the somalier invocation..
## - sites_vcf: absolute path to a <sites>.vcf.gz file, which is a VCF of known polymorphic sites
## - ref_fasta: absolute path to a reference fasta file
## - pedigree: an optional but strongly recommended pedigree file from which to calculate or infer relateness
## - infer: true or false; infer first-degree relationships between samples based on pedigree; default = false
##	https://github.com/brentp/somalier/wiki/pedigree-inference. Note: do not try to infer relatedness
##      in consanguineous families without a pedigree file.
## - output_base_name: An optional base name for the relatedness output file set.
#
##
## Outputs :
## - A <sample_name>.somalier file of extracted sites for each bam; passed to the somalier relate invocation. 
## - A set of relatedness files.
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## For program versions, see docker containers. 
##

import "../../tasks/plab/SomalierTasks.wdl" as Somalier

struct BamUnit {
  File input_bam
  File input_bam_index
  String output_base_name
}

# WORKFLOW DEFINITION
workflow SomalierRelateBams {
  input {
    Array[BamUnit] sample_bam_units
    File sites_vcf
    File ref_fasta
    Boolean infer = false
    File? pedigree

    String somalier_docker = "brentp/somalier:v0.2.15"
  }

  scatter ( next  in sample_bam_units) {
    File input_bam = next.input_bam
    File input_bam_index = next.input_bam_index
    String output_base_name = next.output_base_name

    # Extract sites.
    call Somalier.ExtractSitesSingleSample {
      input:
        input_bam = next.input_bam,
        input_bam_index = input_bam_index,
        sites_vcf = sites_vcf,
        ref_fasta = ref_fasta,
	output_base_name = output_base_name,

        docker = somalier_docker
    }
  }

  call Somalier.Relate {
    input: 
      extracted_files = ExtractSitesSingleSample.output_file,
      pedigree = pedigree,
      infer = infer,
      output_base_name = output_base_name,

      docker = somalier_docker
  }

  # Outputs that will be retained when execution is complete
  output {
    File result_html = Relate.result_html
    File result_groups = Relate.result_groups
    File result_pairs = Relate.result_pairs
    File result_samples = Relate.result_samples
  }
}

