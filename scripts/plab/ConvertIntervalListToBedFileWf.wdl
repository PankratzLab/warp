version 1.0

## This standalone WDL workflow converts a Picard interval list,
## to a BED file.

# WORKFLOW DEFINITION
workflow ConvertIntervalListToBedFile {

  String pipeline_version = "3.1.5"

  input {
    File input_interval_list
    String output_base_name
  }

  call ConvertIntervalList {
    input:
      input_interval_list = input_interval_list,
      output_base_name = output_base_name,

      docker = "us.gcr.io/broad-gotc-prod/picard-cloud:2.26.10"
  }

  # Outputs that will be retained when execution is complete
  output {
    File bed_file = ConvertIntervalList.output_file
  }
  meta {
    allowNestedInputs: true
  }
}

# TASK DEFINITIONS
# Convert Picard interval list to BED format file.
task ConvertIntervalList {
  input {
    File input_interval_list
    String output_base_name

    String docker
  }

  command {
    java -Xms5000m -Xmx6500m -jar /usr/picard/picard.jar \
      IntervalListToBed \
      INPUT=~{input_interval_list} \
      OUTPUT="~{output_base_name}.bed" \
  }
  runtime {
    docker: docker
  }
  output {
    File output_file = "~{output_base_name}.bed"
  }
}
