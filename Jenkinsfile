#!groovy

@Library('fedora-pipeline-library@distgit') _

import groovy.json.JsonBuilder


def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'Run tier-0 tests from dist-git',
    testCategory: 'functional',
    testType: 'tier0-tf',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/dist-git-pipeline',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]
def artifactId
def additionalArtifactIds
def testingFarmRequestId
def testingFarmResult
def xunit

def repoUrl
def testType


pipeline {

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', artifactNumToKeepStr: '100'))
        timeout(time: 4, unit: 'HOURS')
    }

    agent {
        label 'master'
    }

    parameters {
        string(name: 'ARTIFACT_ID', defaultValue: '', trim: true, description: '"koji-build:&lt;taskId&gt;" for Koji builds; Example: koji-build:46436038')
        string(name: 'ADDITIONAL_ARTIFACT_IDS', defaultValue: '', trim: true, description: 'A comma-separated list of additional ARTIFACT_IDs')
    }

    environment {
        TESTING_FARM_API_KEY = credentials('testing-farm-api-key')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    artifactId = params.ARTIFACT_ID
                    additionalArtifactIds = params.ADDITIONAL_ARTIFACT_IDS
                    setBuildNameFromArtifactId(artifactId: artifactId)

                    if (!artifactId) {
                        abort('ARTIFACT_ID is missing')
                    }

                    // FIXME: normally we would use "branch: env.BRANCH_NAME" here
                    // and it would nicely translate to master (for rawhide), etc.
                    // However, since we are running from non-standard "tmt" branch now (Bruno is working on the master branch),
                    // we simply hardcode "master" branch here.

                    repoUrl = getRepoUrlFromTaskId("${getIdFromArtifactId(artifactId: artifactId)}")
                    if (repoHasStiTests(repoUrl: repoUrl, branch: 'master')) {
                        testType = 'sti'
                    } else if (repoHasTmtTests(repoUrl: repoUrl, branch: 'master')) {
                        testType = 'fmf'
                    }

                    if (!testType) {
                        abort('No dist-git tests (STI/FMF) were found, skipping...')
                    }
                }
                sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
            }
        }

        stage('Schedule Test') {
            steps {
                script {
                    def artifacts = []
                    getIdFromArtifactId(artifactId: artifactId, additionalArtifactIds: additionalArtifactIds).split(',').each { taskId ->
                        artifacts.add([id: "${taskId}", type: "fedora-koji-build"])
                    }

                    def requestPayload = """
                        {
                            "api_key": "${env.TESTING_FARM_API_KEY}",
                            "test": {
                                "${testType}": {
                                    "url": "${repoUrl}",
                                    "ref": "master"
                                }
                            },
                            "environments": [
                                {
                                    "arch": "x86_64",
                                    "os": {
                                        "compose": "Fedora-Rawhide"
                                    },
                                    "artifacts": ${new JsonBuilder( artifacts ).toPrettyString()}
                                }
                            ]
                        }
                    """
                    echo "${requestPayload}"
                    def response = submitTestingFarmRequest(payload: requestPayload)
                    testingFarmRequestId = response['id']
                }
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
            }
        }

        stage('Wait for Test Results') {
            steps {
                script {
                    testingFarmResult = waitForTestingFarmResults(requestId: testingFarmRequestId, timeout: 60)
                    echo "${testingFarmResult}"
                    xunit = testingFarmResult.get('result', [:]).get('xunit', '')
                    evaluateTestingFarmResults(testingFarmResult)
                }
            }
        }
    }

    post {
        always {
            // Show XUnit results in Jenkins, if available
            script {
                if (xunit) {
                    node('pipeline-library') {
                        writeFile file: 'tfxunit.xml', text: "${xunit}"
                        sh script: "tfxunit2junit --docs-url ${pipelineMetadata['docs']} tfxunit.xml > xunit.xml"
                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'xunit.xml')
                    }
                }
            }
        }
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: isPullRequest())
        }
    }
}
