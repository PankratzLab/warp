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


import "../../../tasks/plab/AnnotationTasks.wdl" as Annotate
import "../../../structs/plab/AnnotationStructs.wdl"

# WORKFLOW DEFINITION
workflow AnnotateVcfs {

  String pipeline_version = "1.0.0"

  input {
    Array[VcfAndIndex] vcf_units
    File ref_fasta
    File ref_fasta_index
  }

  scatter ( unit in vcf_units ) {
    call Annotate.SplitMultiallelics {
      input:
	vcf_unit = unit,
    	ref_fasta = ref_fasta,
	ref_fasta_index = ref_fasta_index
    }

    call Annotate.VariantEffectPredictor {
      input:
	input_vcf = SplitMultiallelics.output_vcf,
	input_vcf_index = SplitMultiallelics.output_vcf_index,
	output_base_name = unit.output_base_name,
    	ref_fasta = ref_fasta,
	ref_fasta_index = ref_fasta_index
    }
  }

  # Outputs that will be retained when execution is complete
  output {
    Array[File] split_vcf = SplitMultiallelics.output_vcf
    Array[File] split_vcf_index = SplitMultiallelics.output_vcf_index
  }
  meta {
    allowNestedInputs: true
  }
}
