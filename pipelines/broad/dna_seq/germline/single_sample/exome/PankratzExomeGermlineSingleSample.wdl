version 1.0

## This WDL pipeline implements data pre-processing and initial variant calling (GVCF
## generation) according to the GATK Best Practices (June 2016) for germline SNP and
## Indel discovery in human exome sequencing data, beginning from paired fastq files.
##
## Requirements/expectations :
## - Human exome sequencing data in 2 paired-end read fastq files
## - One or more read groups, one per fastq pair, all belonging to a single sample (SM)
## - Input fastq file pairs must additionally comply with the following requirements:
## - - filenames all have the same suffix (we use ".fastq.gz")
## - - reads are provided in query-sorted order
## - - all reads must have an RG tag
## - GVCF output names must end in ".g.vcf.gz"
## - Reference genome must be Hg38 with ALT contigs

import "../../../../../../tasks/broad/PairedFastqsToAlignedBam.wdl" as FastqsToBam
import "../../../../../../tasks/broad/AggregatedBamQC.wdl" as AggregatedQC
import "../../../../../../tasks/broad/Qc.wdl" as QC
import "../../../../../../tasks/broad/BamProcessing.wdl" as Processing
import "../../../../../../pipelines/broad/dna_seq/germline/variant_calling/VariantCalling.wdl" as ToGvcf
import "../../../../../../structs/dna_seq/DNASeqStructs.wdl"

# WORKFLOW DEFINITION
workflow PankratzExomeGermlineSingleSample {

  String pipeline_version = "3.1.5"


  input {
    PapiSettings papi_settings
    SampleAndPairedFastqs sample_and_paired_fastqs
    DNASeqSingleSampleReferences references
    VariantCallingScatterSettings scatter_settings

    File? fingerprint_genotypes_file
    File? fingerprint_genotypes_index

    File target_interval_list
    File bait_interval_list
    String bait_set_name

    Boolean provide_bam_output = false
    Boolean dont_use_soft_clipped_bases = false
  }

  # Not overridable:
  Float lod_threshold = -10.0
  String cross_check_fingerprints_by = "READGROUP"
  String recalibrated_bam_basename = sample_and_paired_fastqs.base_file_name + ".aligned.duplicates_marked.recalibrated"

  String final_gvcf_base_name = select_first([sample_and_paired_fastqs.final_gvcf_base_name, sample_and_paired_fastqs.base_file_name])


  call Processing.GenerateSubsettedContaminationResources {
    input:
        bait_set_name = bait_set_name,
        target_interval_list = target_interval_list,
        contamination_sites_bed = references.contamination_sites_bed,
        contamination_sites_mu = references.contamination_sites_mu,
        contamination_sites_ud = references.contamination_sites_ud,
        preemptible_tries = papi_settings.preemptible_tries
  }

   call FastqsToBam.PairedFastqsToAlignedBam {
     input:
       sample_and_paired_fastqs = sample_and_paired_fastqs,
       references = references,
       papi_settings = papi_settings,

       contamination_sites_ud = GenerateSubsettedContaminationResources.subsetted_contamination_ud,
       contamination_sites_bed = GenerateSubsettedContaminationResources.subsetted_contamination_bed,
       contamination_sites_mu = GenerateSubsettedContaminationResources.subsetted_contamination_mu,

       cross_check_fingerprints_by = cross_check_fingerprints_by,
       haplotype_database_file = references.haplotype_database_file,
       lod_threshold = lod_threshold,
       recalibrated_bam_basename = recalibrated_bam_basename
  }

  call AggregatedQC.AggregatedBamQC {
    input:
      base_recalibrated_bam = PairedFastqsToAlignedBam.output_bam,
      base_recalibrated_bam_index = PairedFastqsToAlignedBam.output_bam_index,
      base_name = sample_and_paired_fastqs.base_file_name,
      sample_name = sample_and_paired_fastqs.sample_name,
      recalibrated_bam_base_name = recalibrated_bam_basename,
      haplotype_database_file = references.haplotype_database_file,
      references = references,
      fingerprint_genotypes_file = fingerprint_genotypes_file,
      fingerprint_genotypes_index = fingerprint_genotypes_index,
      papi_settings = papi_settings
  }

  call ToGvcf.VariantCalling as BamToGvcf {
    input:
      calling_interval_list = references.calling_interval_list,
      evaluation_interval_list = references.evaluation_interval_list,
      haplotype_scatter_count = scatter_settings.haplotype_scatter_count,
      break_bands_at_multiples_of = scatter_settings.break_bands_at_multiples_of,
      contamination = PairedFastqsToAlignedBam.contamination,
      input_bam = PairedFastqsToAlignedBam.output_bam,
      input_bam_index = PairedFastqsToAlignedBam.output_bam_index,
      ref_fasta = references.reference_fasta.ref_fasta,
      ref_fasta_index = references.reference_fasta.ref_fasta_index,
      ref_dict = references.reference_fasta.ref_dict,
      dbsnp_vcf = references.dbsnp_vcf,
      dbsnp_vcf_index = references.dbsnp_vcf_index,
      base_file_name = sample_and_paired_fastqs.base_file_name,
      final_vcf_base_name = final_gvcf_base_name,
      dont_use_soft_clipped_bases = dont_use_soft_clipped_bases,
      agg_preemptible_tries = papi_settings.agg_preemptible_tries
  }

  call QC.CollectHsMetrics as CollectHsMetrics {
    input:
      input_bam = PairedFastqsToAlignedBam.output_bam,
      input_bam_index = PairedFastqsToAlignedBam.output_bam_index,
      metrics_filename = sample_and_paired_fastqs.base_file_name + ".hybrid_selection_metrics",
      ref_fasta = references.reference_fasta.ref_fasta,
      ref_fasta_index = references.reference_fasta.ref_fasta_index,
      target_interval_list = target_interval_list,
      bait_interval_list = bait_interval_list,
      preemptible_tries = papi_settings.agg_preemptible_tries
  }

  if (provide_bam_output) {
    File provided_output_bam = PairedFastqsToAlignedBam.output_bam
    File provided_output_bam_index = PairedFastqsToAlignedBam.output_bam_index
  }

  # Outputs that will be retained when execution is complete
  output {
    File quality_yield_metrics = PairedFastqsToAlignedBam.quality_yield_metrics

    Array[File] unsorted_read_group_base_distribution_by_cycle_pdf = PairedFastqsToAlignedBam.unsorted_read_group_base_distribution_by_cycle_pdf
    Array[File] unsorted_read_group_base_distribution_by_cycle_metrics = PairedFastqsToAlignedBam.unsorted_read_group_base_distribution_by_cycle_metrics
    Array[File] unsorted_read_group_insert_size_histogram_pdf = PairedFastqsToAlignedBam.unsorted_read_group_insert_size_histogram_pdf
    Array[File] unsorted_read_group_insert_size_metrics = PairedFastqsToAlignedBam.unsorted_read_group_insert_size_metrics
    Array[File] unsorted_read_group_quality_by_cycle_pdf = PairedFastqsToAlignedBam.unsorted_read_group_quality_by_cycle_pdf
    Array[File] unsorted_read_group_quality_by_cycle_metrics = PairedFastqsToAlignedBam.unsorted_read_group_quality_by_cycle_metrics
    Array[File] unsorted_read_group_quality_distribution_pdf = PairedFastqsToAlignedBam.unsorted_read_group_quality_distribution_pdf
    Array[File] unsorted_read_group_quality_distribution_metrics = PairedFastqsToAlignedBam.unsorted_read_group_quality_distribution_metrics

    File read_group_alignment_summary_metrics = AggregatedBamQC.read_group_alignment_summary_metrics

    File? cross_check_fingerprints_metrics = PairedFastqsToAlignedBam.cross_check_fingerprints_metrics

    File selfSM = PairedFastqsToAlignedBam.selfSM
    Float contamination = PairedFastqsToAlignedBam.contamination

    File calculate_read_group_checksum_md5 = AggregatedBamQC.calculate_read_group_checksum_md5

    File agg_alignment_summary_metrics = AggregatedBamQC.agg_alignment_summary_metrics
    File agg_bait_bias_detail_metrics = AggregatedBamQC.agg_bait_bias_detail_metrics
    File agg_bait_bias_summary_metrics = AggregatedBamQC.agg_bait_bias_summary_metrics
    File agg_insert_size_histogram_pdf = AggregatedBamQC.agg_insert_size_histogram_pdf
    File agg_insert_size_metrics = AggregatedBamQC.agg_insert_size_metrics
    File agg_pre_adapter_detail_metrics = AggregatedBamQC.agg_pre_adapter_detail_metrics
    File agg_pre_adapter_summary_metrics = AggregatedBamQC.agg_pre_adapter_summary_metrics
    File agg_quality_distribution_pdf = AggregatedBamQC.agg_quality_distribution_pdf
    File agg_quality_distribution_metrics = AggregatedBamQC.agg_quality_distribution_metrics
    File agg_error_summary_metrics = AggregatedBamQC.agg_error_summary_metrics

    File? fingerprint_summary_metrics = AggregatedBamQC.fingerprint_summary_metrics
    File? fingerprint_detail_metrics = AggregatedBamQC.fingerprint_detail_metrics

    File duplicate_metrics = PairedFastqsToAlignedBam.duplicate_metrics
    File? output_bqsr_reports = PairedFastqsToAlignedBam.output_bqsr_reports

    File gvcf_summary_metrics = BamToGvcf.vcf_summary_metrics
    File gvcf_detail_metrics = BamToGvcf.vcf_detail_metrics

    File hybrid_selection_metrics = CollectHsMetrics.metrics

    File? output_bam = provided_output_bam
    File? output_bam_index = provided_output_bam_index

    File output_vcf = BamToGvcf.output_vcf
    File output_vcf_index = BamToGvcf.output_vcf_index
  }
  meta {
    allowNestedInputs: true
  }
}
