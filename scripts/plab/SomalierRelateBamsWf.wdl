version 1.0
## This WDL invokes the somalier tool (https://github.com/brentp/somalier) to evaluate relatedness
## among a set of BAM files. 
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - sample_bam_units : An array of dictionaries, each containing the sample name, absolute path to 
##	the bam file, and absolute path to the bam index file. Note that somalier implicitly assumes
##	that the index files are co-located with the bam files. Note also that in order for Cromwell
##	to copy or link the index files into the container at execution time, it is necessary to 
##	explicitly pass the index file paths into the ExtractSites task even though the value is not
##	passed to the somalier invocation..
## - sites_vcf: A path to a <sites>.vcf.gz file, which is a VCF of known polymorphic sites
## - ref_fasta:A path to a reference fasta file
## - pedigree: An optional but strongly recommended pedigree file from which to calculate or infer relateness
## - infer: true or false; infer first-degree relationships between samples based on pedigree; default = false
##	https://github.com/brentp/somalier/wiki/pedigree-inference
## - output_base_name: An optional base name for the relatedness output file set.
#
##
## Outputs :
## - A <sample_name>.somalier file of extracted sites; passed to the somalier relate invocation. 
## - A set of relatedness files.
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##

struct SampleBamUnit {
  String sample_name
  File bam_path
  File bam_index_path
}

# WORKFLOW DEFINITION
workflow SomalierRelateBamsWf {
  input {
    Array[SampleBamUnit] sample_bam_units
    File sites_vcf
    File ref_fasta
    Boolean infer = false
    File? pedigree
    String? sample_base_name
  }

  String somalier_docker = "brentp/somalier:v0.2.15"
  String extract_commandline = "somalier extract --sites $bash_sites_vcf -f $bash_ref_fasta $bash_bam_path"
  String output_base_name = if defined(sample_base_name) then "${sample_base_name}" else "somalier_relate"

  scatter ( next  in sample_bam_units) {
    String sample_name = next.sample_name
    File bam_path = next.bam_path
    File bam_index_path = next.bam_index_path

    # Extract sites.
    call ExtractSites {
      input:
        sample_name = sample_name,
        bam_path = bam_path,
	bam_index_path = bam_index_path,
        sites_vcf = sites_vcf,
        ref_fasta = ref_fasta,
        extract_commandline = extract_commandline,
	output_base_name = output_base_name,
        output_file_name = sample_name + ".somalier",
        docker = somalier_docker
    }
  }

  call RelateBams {
    input: 
      extracted_files = ExtractSites.output_file,
      pedigree = pedigree,
      infer = infer,
      output_base_name = output_base_name,
      docker = somalier_docker
  }
  # Outputs that will be retained when execution is complete
  output {
    Array[File] output_files = ExtractSites.output_file
    File result_html = RelateBams.result_html
    File result_groups = RelateBams.result_groups
    File result_pairs = RelateBams.result_pairs
    File result_samples = RelateBams.result_samples
  }
}

# TASK DEFINITIONS

# Extract sites for calculating relatedness, ancestry, and/or quality metrics from a bam.
task ExtractSites {
  input {
    # Command parameters
    String sample_name
    File bam_path
    File bam_index_path
    File sites_vcf
    File ref_fasta
    String extract_commandline
    String output_base_name
    String output_file_name

    # Runtime parameters
    String docker
  }

  command <<<

  #Set the bash variables needed for the command-line 
  bash_sites_vcf=~{sites_vcf}
  bash_ref_fasta=~{ref_fasta}
  bash_bam_path=~{bam_path}
  ~{extract_commandline}  2> ~{output_file_name}.stderr.log

  mv ~{output_base_name}.somalier ~{output_file_name}

  >>>
  runtime {
    docker: docker
  }
  output {
    File output_file = "~{output_file_name}"
    File? extract_stderr_log = "~{output_file_name}.stderr.log"
  }
}

# Calculate relatedness among samples.
task RelateBams {
  input {
    Array[File] extracted_files
    String output_base_name
    File? pedigree
    Boolean infer

    String docker
  }

  Boolean has_pedigree = defined(pedigree)

  command {
    somalier relate \
      ~{true='--infer ' false="" infer} \
      -o ~{output_base_name} \
      ~{true='--ped ' false="" has_pedigree} \
      ~{default="" pedigree} \
      ~{sep=" " extracted_files} 
  }

  runtime {
    docker: docker
  }
 
  output {
    File result_html = "~{output_base_name}.html"
    File result_groups = "~{output_base_name}.groups.tsv"
    File result_pairs = "~{output_base_name}.pairs.tsv"
    File result_samples = "~{output_base_name}.samples.tsv"
    File? relate_stderr_log = "~{output_base_name}.stderr.log"
  }
}
