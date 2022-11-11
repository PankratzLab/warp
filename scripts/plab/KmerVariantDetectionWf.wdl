version 1.0
## This WDL invokes the RUFUS tool (https://github.com/jandrewrfarrell/RUFUS) to perform k-mer
## based variant detection on a proband bam file, given one or more control bam files. 
##
## Requirements/expectations :
## The workflow takes an input JSON file containing the following: 
## - sample_name : the name of the affected person of interest. Must match the base name of the affected_bam file.
## - affected_bam : the bam file for the affected person of interest (proband sample)
## - affected_bam_index : the index file for the proband bam
## - control_bam_files : an array of file paths for control bams, minimum of one
## - control_bam_index_files : an array of index files in the same order as the control bam files array.
## - reference_fasta : a dictionary of reference genome fasta and index files produced by BWA.
## - kmer_size: an integer specifying the kmer size. The recommended value is 25; do not change this unless
##  		you really know what you are doing.
## - thread_count : an integer number of threads for RUFUS to use. Recommended = 40.
##
## Outputs :
## - A vcf file of k-mer based variant calls. 
##
## Cromwell version support 
## - Successfully tested on v47
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##

struct BwaReferenceFasta {
  File ref_dict
  File ref_fasta
  File ref_fasta_index
  File ref_alt
  File ref_sa
  File ref_amb
  File ref_bwt
  File ref_ann
  File ref_pac
}

# WORKFLOW DEFINITION
workflow KmerVariantDetection {
  input {
    String sample_name
    File affected_bam
    File affected_bam_index
    Array[File] control_bams
    Array[File] control_bam_indices
    BwaReferenceFasta reference_fasta
    Int kmer_size = 25
    Int thread_count = 24

    String rufus_docker = "moldach686/rufus-v1.0"
  }

  call DetectKmerVariants {
    input:
      output_base_name = sample_name, 
      affected_bam = affected_bam,
      affected_bam_index = affected_bam_index,
      control_bams = control_bams,
      control_bam_indices = control_bam_indices,
      reference_fasta = reference_fasta,
      kmer_size = kmer_size,
      thread_count = thread_count,

      docker = rufus_docker
  }
  # Outputs that will be retained when execution is complete
  output {
    File output_files = DetectKmerVariants.output_file
  }
}

# TASK DEFINITIONS

# Detect kmer-based variants on an affected individual (proband sample)
# given a set of one or more non-affected controls.
task DetectKmerVariants {
  input {
    String output_base_name
    File affected_bam
    File affected_bam_index
    Array[File] control_bams
    Array[File] control_bam_indices
    BwaReferenceFasta reference_fasta
    Int kmer_size
    Int thread_count

    String docker
  }

  File affected_index = affected_bam_index
  Array[File] control_indices = control_bam_indices

  command {
    /bin/sh /RUFUS/runRufus.sh \
      -s ~{affected_bam} \
      ~{sep=" -c " control_bams} \
      -t ~{thread_count} \
      -k ~{kmer_size} \
      -r ~{reference_fasta.ref_fasta}
  }

  runtime {
    docker: docker
  }
 
  output {
    File output_file = "~{output_base_name}.bam.generator.V2.overlap.hashcount.fastq.bam.vcf"
  }
}
