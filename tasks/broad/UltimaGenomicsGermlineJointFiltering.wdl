version 1.0

import "../../tasks/broad/UltimaGenomicsWholeGenomeGermlineTasks.wdl" as UltimaFilteringTasks

workflow UltimaGenomicsGermlineJointFiltering {
	input {
		Array[File] vcf
		Array[File] vcf_index
		File sites_only_vcf
		File sites_only_vcf_index

		#TODO delete these inputs
		File python_script = "gs://broad-dsp-spec-ops/scratch/mshand/Jukebox/TestInputs/isolation-forest_v1.py"
		File hyperparameters_json = "gs://broad-dsp-spec-ops/scratch/mshand/Jukebox/TestInputs/new_hyperparameters.json"
		File gatk_jar = "gs://broad-dsp-spec-ops/scratch/mshand/Jukebox/Jars/gatk_LL_scikitlearn_sens_callibrate.jar"

		String? interval_contig

		Float indel_sensitivity_threshold
		Float snp_sensitivity_threshold
		String snp_annotations
		String indel_annotations
	}

	String basename = basename(vcf, ".vcf.gz")

	call UltimaFilteringTasks.ExtractVariantAnnotations as ExtractVariantAnnotationsSNPs {
		input:
			gatk_jar = gatk_jar,
			input_vcf = sites_only_vcf,
			input_vcf_index = sites_only_vcf_index,
			mode = "SNP",
			annotations = snp_annotations,
			resources = "-resource:hapmap,training=true,calibration=true gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz -resource:omni,training=true,calibration=true gs://gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz -resource:1000G,training=true,calibration=false gs://gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz",
			basename = basename,
			interval_contig = interval_contig
	}

	call UltimaFilteringTasks.ExtractVariantAnnotations as ExtractVariantAnnotationsINDELs {
		input:
			gatk_jar = gatk_jar,
			input_vcf = sites_only_vcf,
			input_vcf_index = sites_only_vcf_index,
			mode = "INDEL",
			annotations = indel_annotations,
			resources = "--resource:mills,training=true,calibration=true gs://gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz",
			basename = basename,
			interval_contig = interval_contig
	}

	call UltimaFilteringTasks.TrainVariantAnnotationModel as TrainVariantAnnotationModelSNPs {
		input:
			gatk_jar = gatk_jar,
			annots = ExtractVariantAnnotationsSNPs.annots,
			basename = basename,
			mode_uc = "SNP",
			mode_lc = "snp",
			python_script = python_script,
			hyperparameters_json = hyperparameters_json
	}

	call UltimaFilteringTasks.TrainVariantAnnotationModel as TrainVariantAnnotationModelINDELs {
		input:
			gatk_jar = gatk_jar,
			annots = ExtractVariantAnnotationsINDELs.annots,
			basename = basename,
			mode_uc = "INDEL",
			mode_lc = "indel",
			python_script = python_script,
			hyperparameters_json = hyperparameters_json
	}

	scatter(idx in range(length(vcf))) {
		call UltimaFilteringTasks.ScoreVariantAnnotations as ScoreVariantAnnotationsSNPs {
			input:
				gatk_jar = gatk_jar,
				vcf = vcf[idx],
				vcf_index = vcf_index[idx],
				basename = basename,
				mode = "SNP",
				scoring_python_script = python_script,
				annotations = snp_annotations,
				extracted_training_vcf = ExtractVariantAnnotationsSNPs.extracted_training_vcf,
				extracted_training_vcf_index = ExtractVariantAnnotationsSNPs.extracted_training_vcf_index,
				interval_contig = contig,
				model = TrainVariantAnnotationModelSNPs.scorer,
				resources = "-resource:hapmap,training=false,calibration=true,prior=15 gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz -resource:omni,training=false,calibration=true,prior=12 gs://gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz"
		}

		call UltimaFilteringTasks.ScoreVariantAnnotations as ScoreVariantAnnotationsINDELs {
			input:
				gatk_jar = gatk_jar,
				vcf = ScoreVariantAnnotationsSNPs.output_vcf,
				vcf_index = ScoreVariantAnnotationsSNPs.output_vcf_index,
				basename = basename,
				mode = "INDEL",
				scoring_python_script = python_script,
				annotations = indel_annotations,
				extracted_training_vcf = ExtractVariantAnnotationsINDELs.extracted_training_vcf,
				extracted_training_vcf_index = ExtractVariantAnnotationsINDELs.extracted_training_vcf_index,
				model = TrainVariantAnnotationModelINDELs.scorer,
				resources = "--resource:mills,training=false,calibration=true gs://gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
		}
	}

	output {
		Array[File] variant_filtered_vcf = ScoreVariantAnnotationsINDELs.output_vcf
		Array[File] variant_filtered_vcf_index = ScoreVariantAnnotationsINDELs.output_vcf_index
	}

}
