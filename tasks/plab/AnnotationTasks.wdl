version 1.0

## Tasks for VCF annotation.

import "../../structs/plab/AnnotationStructs.wdl"

task SplitMultiallelics {
  input {
    VcfAndIndex vcf_unit
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    Int max_indel_length

    String gatk_docker = "us.gcr.io/broad-gatk/gatk:4.2.6.1"
  }

  # Reference the index and dict files even though they aren't passed as arguments to gatk so cromwell will see them.
  File input_vcf_index = vcf_unit.input_vcf_index
  File fasta_index = ref_fasta_index
  File reference_dict = ref_dict
  String output_base_name = vcf_unit.output_base_name

  command {
    gatk --java-options "-Xms3000m -Xmx3250m -DGATK_STACKTRACE_ON_USER_EXCEPTION=true" \
      LeftAlignAndTrimVariants \
      -R ~{ref_fasta} \
      -V ~{vcf_unit.input_vcf} \
      -O "~{output_base_name}.vcf.gz" \
      --split-multi-allelics \
      --max-indel-length ~{max_indel_length}
  }

  runtime {
    docker: gatk_docker
  }

  output {
    File output_vcf = "~{output_base_name}.vcf.gz"
    File output_vcf_index = "~{output_base_name}.vcf.gz.tbi"
  }
}

task VariantEffectPredictor {
  input {
    File input_vcf
    File input_vcf_index
    String output_base_name
    File ref_fasta
    File ref_fasta_index
    String vep_pick_string
    String vep_output_format
    String? vep_fields
    File vep_cache_dir
    File? topmed_vcf
    File? topmed_index
    String? topmed_short_name

    String vep_docker = "ensemblorg/ensembl-vep:release_107.0"
  }

  # Reference the index files even though they aren't passed as arguments to vep so cromwell will see them.
  File vcf_index = input_vcf_index
  File fasta_index = ref_fasta_index
  Boolean specify_fields = defined(vep_fields)
  Boolean use_topmed = defined(topmed_vcf)
  File tm_index = if topmed_annotations then topmed_index else None

  parameter_meta {
    vep_cache_dir: {
      description: "VEP reference genome cache",
      localization_optional: true
    }
  }
  
  command {
    vep \
      --cache \
      --dir_cache ~{vep_cache_dir} \
      --merged \
      --everything \
      --flag_pick \
      --pick_order ~{vep_pick_string} \
      --fasta ~{ref_fasta} \
      --~{vep_output_format} \
      --compress_output bgzip \
      -i ~{input_vcf} \
      -o "~{output_base_name}.vep.vcf.gz" \
      ~{true='--fields  ~{vep_fields}' false="" specify_fields} \
      ~{true='--custom  ~{topmed_vcf},~{topmed_short_name},vcf,exact,0,AF_AFR,AF_SAS,AF_AMR,AF_EAS,AF_EUR,AF' false="" use_topmed} \
      --force_overwrite
  }

  runtime {
    docker: vep_docker
  }

  output {
    File output_vcf = "~{output_base_name}.vep.vcf.gz"
    File output_vcf_summary = "~{output_base_name}.vep.vcf.gz_summary.html"
  }
}
