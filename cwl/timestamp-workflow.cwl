#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow

requirements:
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}

inputs:
  input_file: File

steps:
  cp:
    run: cp.cwl
    in:
      input_file: input_file
      output_filename:
        valueFrom: ${ return Date.now().toString() + '.txt'; }
    out:
      [ output_file ]

outputs:
  output_file:
    type: File
    outputSource: cp/output_file
