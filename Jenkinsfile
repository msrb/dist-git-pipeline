#!groovy

@Library('fedora-pipeline-library@pull-requests') _

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

                    currentBuild.result = 'UNSTABLE'
                    error('test')

                    if (!artifactId) {
                        abort('ARTIFACT_ID is missing')
                    }
                }
                // sendMessage(type: 'queued', topic: 'org.centos.prod.ci.dist-git-pr.test.queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: false)
            }
        }

        stage('Schedule Test') {
            steps {
                echo "no-op"
                // sendMessage(type: 'running', topic: 'org.centos.prod.ci.dist-git-pr.test.running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: false)
            }
        }

        stage('Wait for Test Results') {
            steps {
                echo "no-op"
            }
        }
    }

    post {
        success {
            echo "no-op"
            // sendMessage(type: 'complete', topic: 'org.centos.prod.ci.dist-git-pr.test.complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: false)
            // sendMessage(type: 'error', topic: 'org.centos.prod.ci.dist-git-pr.test.error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: false)
        }
        failure {
            echo "no-op"
            // sendMessage(type: 'error', topic: 'org.centos.prod.ci.dist-git-pr.test.error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: false)
        }
        unstable {
            echo "no-op"
            sendMessage(type: 'complete',  topic: 'org.centos.prod.ci.dist-git-pr.test.complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: false)
        }
    }
}
