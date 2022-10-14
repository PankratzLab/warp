version 1.0

## Tasks for VCF annotation.

import "../../structs/plab/AnnotationStructs.wdl"

task SplitMultiallelics {
  input {
    VcfAndIndex vcf_unit
    File ref_fasta

    String docker = "us.gcr.io/broad-gatk/gatk:4.2.6.1"
  }

  # Reference the index even though it isn't passed to gatk so cromwell will see it.
  File input_vcf_index = vcf_unit.input_vcf_index
  String output_base_name = vcf_unit.output_vcf_base_name

  command {
    gatk --java-options "-Xms3000m -Xmx3250m -DGATK_STACKTRACE_ON_USER_EXCEPTION=true" \
      LeftAlignAndTrimVariants \
      -R ~{ref_fasta} \
      -V ~{vcf_unit.input_vcf} \
      -O "~{output_base_name}.vcf.gz" \
      --split-multi-allelics
  }

  runtime {
    docker: docker
  }

  output {
    File output_vcf = "~{output_base_name}.vcf.gz"
    File output_vcf_index = "~{output_base_name}.vcf.gz.tbi"
  }
}

task VariantEffectPredictor {
  input {
    VcfAndIndex vcf_unit
    File ref_fasta

    String docker = "docker pull ensemblorg/ensembl-vep"
  }

  # Reference the index even though it isn't passed to gatk so cromwell will see it.
  File input_vcf_index = vcf_unit.input_vcf_index
  String output_base_name = vcf_unit.output_vcf_base_name

  command {
    vep \
      --cache \
      --merged \
      --everything \
      --most_severe \
      --regulatory \
      --fasta ~{ref_fasta} \
      --vcf \
      --compress_output bgzip \
      -i ~{vcf_unit.input_vcf} \
      -o "~{output_base_name}.vep.vcf.gz" \
      --force_overwrite
  }

  runtime {
    docker: vep_docker
  }

  output {
    File output_vcf = "~{output_base_name}.vep.vcf.gz"
    File output_vcf_index = "~{output_base_name}.vep.vcf.gz.tbi"
  }
}
