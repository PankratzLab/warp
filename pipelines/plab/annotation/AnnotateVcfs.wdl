version 1.0

## This WDL pipeline implements the Pankratz Lab vcf annotation pipeline, taking as
## input .vcf.gz files produced by the GATK4 JointGenotyping pipeline. Multiallelic
## sites are first split using gatk; the resulting vcf(s) are then passed through
## several annotation tools, with the output of one tool becoming the input of the
## next so that annotations are cumulative.
##
## Requirements/expectations :
## - One or more vcfs produced by GATK4 JointGenotyping
## - Reference genome (Hg38 with ALT contigs)
## - Optionally, the default maximum indel length can be overridden in the input JSON.
## - Optionally, the default pick string ("rank) can be overridden in the input JSON.
## - Path to the VEP reference genome cache
## - Optional custom TOPmed database resource (vcf + index)
## - Short name for TOPmed annotations in the vcf, recommended = "TOPMED_<release_date>"


import "../../../tasks/plab/AnnotationTasks.wdl" as Annotate
import "../../../structs/plab/AnnotationStructs.wdl"

# WORKFLOW DEFINITION
workflow AnnotateVcfs {

  String pipeline_version = "1.0.0"

  input {
    Array[VcfAndIndex] vcf_units
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    Int max_indel_length = 200
    String vep_pick_string = "rank"
    String vep_output_format = "vcf"
    String? vep_fields
    File vep_cache_dir
    String vep_plugin_dir = ""
    File? topmed_vcf
    File? topmed_index
    String? topmed_short_name
    Boolean has_cadd_plugin = false
    Array[String] cadd_data_sources = []
    Array[String] cadd_index_files = []
    String cadd_plugin_version = ""
  }

  String cadd_cmd = "--plugin CADD,$bash_cadd_sources"
  
  scatter ( unit in vcf_units ) {
    call Annotate.SplitMultiallelics {
      input:
	vcf_unit = unit,
    	ref_fasta = ref_fasta,
	ref_fasta_index = ref_fasta_index,
	ref_dict = ref_dict,
	max_indel_length = max_indel_length
    }

    if( !has_cadd_plugin ) {
        call Annotate.VariantEffectPredictor {
	      input:
		input_vcf = SplitMultiallelics.output_vcf,
		input_vcf_index = SplitMultiallelics.output_vcf_index,
		output_base_name = unit.output_base_name,
    		ref_fasta = ref_fasta,
		ref_fasta_index = ref_fasta_index,
		vep_pick_string = vep_pick_string,
		vep_output_format = vep_output_format,
		vep_fields = vep_fields,
		vep_cache_dir = vep_cache_dir,
		topmed_vcf = topmed_vcf,
		topmed_index = topmed_index,
		topmed_short_name = topmed_short_name,
    	}
    }    
    
    if( has_cadd_plugin ) {
        call Annotate.VariantEffectPredictorWithPlugin {
	      input:
		input_vcf = SplitMultiallelics.output_vcf,
		input_vcf_index = SplitMultiallelics.output_vcf_index,
		output_base_name = unit.output_base_name,
    		ref_fasta = ref_fasta,
		ref_fasta_index = ref_fasta_index,
		vep_pick_string = vep_pick_string,
		vep_output_format = vep_output_format,
		vep_fields = vep_fields,
		vep_cache_dir = vep_cache_dir,
		vep_plugin_dir = vep_plugin_dir,
		topmed_vcf = topmed_vcf,
		topmed_index = topmed_index,
		topmed_short_name = topmed_short_name,
		has_cadd_plugin = has_cadd_plugin,
		cadd_data_sources = cadd_data_sources,
		cadd_index_files = cadd_index_files,
		cadd_plugin_version = cadd_plugin_version,
		cadd_cmd = cadd_cmd
    	}
    }
    
    File vep_vcf = selectFirst(VariantEffectPredictorWithPlugin.output_vcf, VariantEffectPredictor.output_vcf)
    
    call Annotate.IndexAnnotatedVcf {
      input:
	input_vcf = vep_vcf
    }
  }

  # Outputs that will be retained when execution is complete
  output {
    Array[File] annotated_vcf = selectFirst(VariantEffectPredictorWithPlugin.output_vcf, VariantEffectPredictor.output_vcf)
    Array[File] annotated_vcf_summary = selectFirst(VariantEffectPredictorWithPlugin.output_vcf_summary, VariantEffectPredictor.output_vcf_summary)
    Array[File] annotated_vcf_index = IndexAnnotatedVcf.output_vcf_index
  }
  meta {
    allowNestedInputs: true
  }
}
