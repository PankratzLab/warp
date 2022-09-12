version 1.0

# WORKFLOW DEFINITION
workflow CollectVariantCallingMetricsWf {
  input {
    File input_vcf 
    File input_vcf_index
    String metrics_basename 
    File dbsnp_vcf 
    File dbsnp_vcf_index
    File ref_dict 
    File evaluation_interval_list 
    Boolean is_gvcf
    Int preemptible_tries 

    String gatk_docker = "broadinstitute/gatk:latest"
    String gatk_path = "/gatk/gatk"
  }

  # Collect variant calling metrics for gvcf
  call CollectVariantCallingMetrics {
    input:
      input_vcf = input_vcf,
      input_vcf_index = input_vcf_index,
      metrics_basename = metrics_basename,
      dbsnp_vcf = dbsnp_vcf,
      dbsnp_vcf_index = dbsnp_vcf_index,
      ref_dict = ref_dict,
      evaluation_interval_list = evaluation_interval_list,
      is_gvcf = is_gvcf,
      preemptible_tries = preemptible_tries,
  }

  # Outputs that will be retained when execution is complete
  output {
    File summary_metrics = CollectVariantCallingMetrics.summary_metrics
    File detail_metrics = CollectVariantCallingMetrics.detail_metrics
  }
}

# TASK DEFINITIONS

# Collect variant calling metrics
task CollectVariantCallingMetrics {
  input {
    # Command parameters
    File input_vcf 
    File input_vcf_index
    String metrics_basename
    File dbsnp_vcf
    File dbsnp_vcf_index
    File ref_dict 
    File evaluation_interval_list
    Boolean is_gvcf

    # Runtime parameters
    Int preemptible_tries
  }

  Int disk_size = ceil(size(input_vcf, "GiB") + size(dbsnp_vcf, "GiB")) + 20

  command {
    java -Xms2000m -Xmx2500m -jar /usr/picard/picard.jar \
    CollectVariantCallingMetrics \
    INPUT=~{input_vcf} \
    OUTPUT=~{metrics_basename} \
    DBSNP=~{dbsnp_vcf} \
    SEQUENCE_DICTIONARY=~{ref_dict} \
    TARGET_INTERVALS=~{evaluation_interval_list} \
    GVCF_INPUT=~{is_gvcf} \
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/picard-cloud:2.26.10"
    preemptible: preemptible_tries
    memory: "3000 MiB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File summary_metrics = "~{metrics_basename}.variant_calling_summary_metrics"
    File detail_metrics = "~{metrics_basename}.variant_calling_detail_metrics"
  }
}

