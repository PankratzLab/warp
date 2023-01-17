version 1.0

## Tasks for the somalier pedigree analysis. 
## NOTE: It is preferable to run somalier ancestry from the command line
## 	 rather than within a workflow. Cromwell copies 2507 resource files for
##	 each sample analyzed for ancestry, which wastes both disk space and
##	 compute time.

# Extract sites for calculating relatedness and quality metrics from a bam.
task ExtractSitesSingleSample {
  input {
    # Command parameters
    File input_bam
    File input_bam_index
    File sites_vcf
    File ref_fasta
    String output_file_name

    # Runtime parameters
    String docker
  }

  File bam_index = input_bam_index
  command <<<

  somalier extract --sites ~{sites_vcf} \
    -f ~{ref_fasta} \
    ~{input_bam} \
    2> ~{output_file_name}.stderr.log

  >>>
  runtime {
    docker: docker
  }
  output {
    File output_file = "~{output_file_name}"
    File? extract_stderr_log = "~{output_file_name}.stderr.log"
  }
}

# Extract sites for calculating relatedness and quality metrics from
# a multi-sample vcf.
task ExtractSitesMultiSampleVcf {
  input {
    # Command parameters
    File input_vcf
    File input_vcf_index
    File sites_vcf
    File ref_fasta
    String output_file_name

    # Runtime parameters
    String docker
  }

  File index_file = input_vcf_index
  command <<<
    export SOMALIER_REPORT_ALL_PAIRS=1
    somalier extract --sites ~{sites_vcf} \
      -f ~{ref_fasta} \
      ~{input_vcf} \
      2> ~{output_file_name}.stderr.log

  >>>
  runtime {
    docker: docker
  }
  output {
    Array[File] output_files = glob("*.somalier")
    File? extract_stderr_log = "~{output_file_name}.stderr.log"
  }
}


# Calculate relatedness among samples.
task Relate {
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
  }
}

