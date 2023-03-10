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

    String vep_docker = "quay.io/jlanej/vep-plugin"
  }
  
  # Reference the index files even though they aren't passed as arguments to vep so cromwell will see them.
  File vcf_index = input_vcf_index
  File fasta_index = ref_fasta_index
  File tm_index = topmed_index
  
  # Access the topmed vcf as a file object so Cromwell will substitute the local path for us.
  File tm = topmed_vcf
  String specify_fields = if( defined(vep_fields) ) then "--fields  ~{vep_fields}" else ""
  String topmed_attrs = if( defined(topmed_vcf) ) then ",~{topmed_short_name},vcf,exact,0,AF_AFR,AF_SAS,AF_AMR,AF_EAS,AF_EUR,AF" else ""
  
  # Tack information about TOPMed annotations onto the output filenames.
  String topmed = if( defined(topmed_short_name) ) then "_" + topmed_short_name else ""
  String output_file_name = output_base_name + topmed

  parameter_meta {
    vep_cache_dir: {
      description: "VEP reference genome cache",
      localization_optional: true
    }
  }
  
  command <<<
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
      -o "~{output_file_name}.vep.vcf.gz" \
      --force_overwrite \
      --offline \
      ~{specify_fields} \
      ~{if defined(topmed_vcf) then "--custom " + topmed_vcf + topmed_attrs else ""} 
  >>>

  runtime {
    docker: vep_docker
  }

  output {
    File output_vcf = "~{output_file_name}.vep.vcf.gz"
    File output_vcf_summary = "~{output_file_name}.vep.vcf.gz_summary.html"
  }
}

task VariantEffectPredictorWithPlugin {
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
    File vep_plugin_dir
    File? topmed_vcf
    File? topmed_index
    String? topmed_short_name
    Boolean has_cadd_plugin
    Array[String] cadd_data_sources
    Array[String] cadd_index_files
    String cadd_plugin_version
    String cadd_cmd

    String vep_docker = "quay.io/jlanej/vep-plugin"
  }
  
  # Reference the index files even though they aren't passed as arguments to vep so cromwell will see them.
  File vcf_index = input_vcf_index
  File fasta_index = ref_fasta_index
  File tm_index = topmed_index
  
  # Access the topmed vcf as a file object so Cromwell will substitute the local path for us.
  File tm = topmed_vcf
  String specify_fields = if( defined(vep_fields) ) then "--fields  ~{vep_fields}" else ""
  String topmed_attrs = if( defined(topmed_vcf) ) then ",~{topmed_short_name},vcf,exact,0,AF_AFR,AF_SAS,AF_AMR,AF_EAS,AF_EUR,AF" else ""
  
  # Tack information about TOPMed and/or CADD annotations onto the output filenames.
  String topmed = if( defined(topmed_short_name) ) then "_" + topmed_short_name else ""
  String cadd = if( has_cadd_plugin ) then "_" + cadd_plugin_version else ""
  String output_file_name = output_base_name + topmed + cadd

  # Declare variables for the CADD plugin data sources.
  String src1 = cadd_data_sources[0]
  String src2 = cadd_data_sources[1]
  
  parameter_meta {
    vep_cache_dir: {
      description: "VEP reference genome cache",
      localization_optional: true
    }
  }
  
  command <<<
    export PERL5LIB=$PERL5LIB:~{vep_plugin_dir}
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
      -o "~{output_file_name}.vep.vcf.gz" \
      --force_overwrite \
      --offline \
      ~{specify_fields} \
      ~{if defined(topmed_vcf) then "--custom " + topmed_vcf + topmed_attrs else ""} \
      ~{if has_cadd_plugin then "--plugin CADD," + vep_cache_dir + "/" + src1 + "," + vep_cache_dir + "/" + src2 else ""}
  >>>

  runtime {
    docker: vep_docker
  }

  output {
    File output_vcf = "~{output_file_name}.vep.vcf.gz"
    File output_vcf_summary = "~{output_file_name}.vep.vcf.gz_summary.html"
  }
}

task IndexAnnotatedVcf {
  input{
    File input_vcf

    String bcftools_docker = "staphb/bcftools:1.11"
  }
  String output_file_name = basename(input_vcf) + ".tbi"
      
  command {
    bcftools index -t -o "~{output_file_name}" ~{input_vcf}
  }

  runtime {
    docker: bcftools_docker
  }

  output {
    File output_vcf_index = "~{output_file_name}"
  }  
}

task GatherAndIndexVcfs {
  input {
    Array[File] input_vcfs
    String output_vcf_name
 
    String bcftools_docker = "staphb/bcftools:1.11"
  }
  
  command {
    bcftools concat ~{sep=' ' input_vcfs} -Oz -o "~{output_vcf_name}"
    bcftools index -t ~{output_vcf_name}
  }

  runtime {
    docker: bcftools_docker
  }

  output {
    File output_vcf = "~{output_vcf_name}"
    File output_vcf_index = "~{output_vcf_name}.tbi"
  }
}

task VepFilterVcf {
  input {
    File input_vcf
    Array[String] filters
    String output_base_name
    String filter_description = ""

    String vep_docker = "quay.io/jlanej/vep-plugin"
  }

  String output_vcf_name = output_base_name + "_" + filter_description + ".vcf"

  command {
    filter_vep \
      -i ~{input_vcf} \
      --format "vcf" \
      --gz \
      --force_overwrite \
      -o ~{output_vcf_name} \
      ~{sep=" " filters}
  }

  runtime {
    docker: vep_docker
  }

  output {
    File output_vcf = "~{output_vcf_name}"
  }
}
