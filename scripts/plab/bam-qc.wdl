version 1.0

## This standalone WDL workflow calculates QC metrics on a sorted, aligned,
## duplicate-marked BAM file plus index.

# WORKFLOW DEFINITION
workflow AlignedBamQcWf {

  String pipeline_version = "3.1.5"

  input {
    File input_bam
    File input_bam_index
    String output_bam_prefix
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Boolean collect_gc_bias_metrics = true
    Int preemptible_tries
  }

  call CollectBamQualityMetrics {
    input:
      input_bam = input_bam,
      input_bam_index = input_bam_index,
      output_bam_prefix = output_bam_prefix,
      ref_dict = ref_dict,
      ref_fasta = ref_fasta,
      ref_fasta_index = ref_fasta_index,
      collect_gc_bias_metrics = collect_gc_bias_metrics,
      preemptible_tries = preemptible_tries
  }

  # Outputs that will be retained when execution is complete
  output {
    File alignment_summary_metrics = CollectBamQualityMetrics.alignment_summary_metrics
    File gc_bias_detail_metrics = CollectBamQualityMetrics.gc_bias_detail_metrics
    File gc_bias_pdf = CollectBamQualityMetrics.gc_bias_pdf
    File gc_bias_summary_metrics = CollectBamQualityMetrics.gc_bias_summary_metrics
  }
  meta {
    allowNestedInputs: true
  }
}

# TASK DEFINITIONS
# Collect alignment summary and GC bias quality metrics
task CollectBamQualityMetrics {
  input {
    File input_bam
    File input_bam_index
    String output_bam_prefix
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Boolean collect_gc_bias_metrics = true
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GiB") + size(ref_fasta_index, "GiB") + size(ref_dict, "GiB")
  Int disk_size = ceil(size(input_bam, "GiB") + ref_size) + 20

  command {
    # These are optionally generated, but need to exist for Cromwell's sake
    touch ~{output_bam_prefix}.gc_bias.detail_metrics \
      ~{output_bam_prefix}.gc_bias.pdf \
      ~{output_bam_prefix}.gc_bias.summary_metrics

    java -Xms5000m -Xmx6500m -jar /usr/picard/picard.jar \
      CollectMultipleMetrics \
      INPUT=~{input_bam} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      OUTPUT=~{output_bam_prefix} \
      ASSUME_SORTED=true \
      PROGRAM=null \
      PROGRAM=CollectAlignmentSummaryMetrics \
      ~{true='PROGRAM="CollectGcBiasMetrics"' false="" collect_gc_bias_metrics} \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=READ_GROUP
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/picard-cloud:2.26.10"
    memory: "7000 MiB"
    disks: "local-disk " + disk_size + " HDD"
    preemptible: preemptible_tries
  }
  output {
    File alignment_summary_metrics = "~{output_bam_prefix}.alignment_summary_metrics"
    File gc_bias_detail_metrics = "~{output_bam_prefix}.gc_bias.detail_metrics"
    File gc_bias_pdf = "~{output_bam_prefix}.gc_bias.pdf"
    File gc_bias_summary_metrics = "~{output_bam_prefix}.gc_bias.summary_metrics"
  }
}
