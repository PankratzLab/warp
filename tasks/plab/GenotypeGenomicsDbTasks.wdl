version 1.0

task GenotypeGenomicsDb {

  input {
    File workspace_tar
    File interval

    String output_vcf_filename

    File ref_fasta
    File ref_fasta_index
    File ref_dict

    File dbsnp_vcf
    File dbsnp_vcf_index

    Boolean keep_combined_raw_annotations = false
    String? additional_annotation

    # This is needed for gVCFs generated with GATK3 HaplotypeCaller
    Boolean allow_old_rms_mapping_quality_annotation_data = false
    String gatk_docker = "us.gcr.io/broad-gatk/gatk:4.2.6.1"
  }

  parameter_meta {
    interval: {
      localization_optional: true
    }
  }

  command <<<
    set -euo pipefail

    tar -xf ~{workspace_tar}
    WORKSPACE="genomicsdb"

    gatk --java-options "-Xms8000m -Xmx25000m" \
      GenotypeGVCFs \
      -R ~{ref_fasta} \
      -O ~{output_vcf_filename} \
      -D ~{dbsnp_vcf} \
      -G StandardAnnotation -G AS_StandardAnnotation \
      --only-output-calls-starting-in-intervals \
      -V gendb://$WORKSPACE \
      -L ~{interval} \
      ~{"-A " + additional_annotation} \
      ~{true='--allow-old-rms-mapping-quality-annotation-data' false='' allow_old_rms_mapping_quality_annotation_data} \
      ~{true='--keep-combined-raw-annotations' false='' keep_combined_raw_annotations} \
      --merge-input-intervals
  >>>

  runtime {
    memory: "60GB"
    cpu: 2
    docker: gatk_docker
  }

  output {
    File output_vcf = "~{output_vcf_filename}"
    File output_vcf_index = "~{output_vcf_filename}.tbi"
  }
}
