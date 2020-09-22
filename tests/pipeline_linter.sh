#!/bin/bash

if [ $# -ne 1 ]; then
    echo $0: "USAGE: ./pipeline_linter.sh jenkins_filename"
    exit 1
fi

FILE=$1

OUTPUT=$(curl -H "Authorization: OAuth " -X POST -F "jenkinsfile=<$FILE" https://osci-jenkins-2.ci.fedoraproject.org/pipeline-model-converter/validate)

if [[ "$OUTPUT" =~ .*"successfully validated".* ]]; then
  echo $OUTPUT
  exit 0
else
  echo $OUTPUT
  exit 1
fi

