#!groovy

@Library('fedora-pipeline-library@skipped-note') _


def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'Run tier-0 tests from dist-git',
    testCategory: 'functional',
    testType: 'tier0',
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
def config

def repoUrlAndRef
def repoTests

def note

def podYAML = """
spec:
  containers:
  - name: pipeline-agent
    # source: https://github.com/fedora-ci/jenkins-pipeline-library-agent-image
    image: quay.io/fedoraci/pipeline-library-agent:candidate
    tty: true
    alwaysPullImage: true
"""


pipeline {

    options {
        buildDiscarder(logRotator(daysToKeepStr: '45', artifactNumToKeepStr: '100'))
        timeout(time: 12, unit: 'HOURS')
    }

    agent {
        label 'dist-git'
    }

    parameters {
        string(name: 'ARTIFACT_ID', defaultValue: '', trim: true, description: '"koji-build:&lt;taskId&gt;" for Koji builds; Example: koji-build:46436038')
        string(name: 'ADDITIONAL_ARTIFACT_IDS', defaultValue: '', trim: true, description: 'A comma-separated list of additional ARTIFACT_IDs')
        string(name: 'TEST_PROFILE', defaultValue: 'f34', trim: true, description: 'A name of the test profile to use; Example: f34')
        string(name: 'TEST_REPO_URL', defaultValue: '', trim: true, description: '(optional) URL to the repository containing tests; followed by "#&lt;ref&gt;", where &lt;ref&gt; is a commit hash; Example: https://src.fedoraproject.org/tests/selinux#ff0784e36758f2fdce3201d907855b0dd74064f9')
        string(name: 'TEST_SCENARIO', defaultValue: '', trim: true, description: '(optional) name of the test scenario; This is only used in special cases, for example when testing dependent components')
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
                    setBuildNameFromArtifactId(artifactId: artifactId, profile: params.TEST_PROFILE)

                    config = loadConfig(profile: params.TEST_PROFILE)

                    if (!artifactId) {
                        abort('ARTIFACT_ID is missing')
                    }

                    if (!TEST_REPO_URL) {
                        repoUrlAndRef = getRepoUrlAndRefFromTaskId("${getIdFromArtifactId(artifactId: artifactId)}")
                    } else {
                        repoUrlAndRef = [url: TEST_REPO_URL.split('#')[0], ref: TEST_REPO_URL.split('#')[1]]
                    }
                    repoTests = repoHasTests(repoUrl: repoUrlAndRef['url'], ref: repoUrlAndRef['ref'])

                    if (repoTests) {
                        sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest())
                    } else {
                        note = "No dist-git tests (STI/TMT) were found in the repository ${repoUrlAndRef[0]}, skipping..."
                        echo "${note}"
                    }
                }
            }
        }

        stage('Schedule Test') {
            when {
                expression { repoTests }
            }
            steps {
                script {
                    def artifacts = []
                    getIdFromArtifactId(artifactId: artifactId, additionalArtifactIds: additionalArtifactIds).split(',').each { taskId ->
                        if (taskId) {
                            artifacts.add([id: "${taskId}", type: "fedora-koji-build"])
                        }
                    }

                    def requestPayload = [
                        api_key: "${env.TESTING_FARM_API_KEY}",
                        test: [:],
                        environments: [
                            [
                                arch: "x86_64",
                                os: [ compose: "${config.compose}" ],
                                artifacts: artifacts
                            ]
                        ]
                    ]

                    if (repoTests['type'] == 'sti') {
                        // add playbooks to run
                        requestPayload['test']['sti'] = repoUrlAndRef
                        requestPayload['test']['sti']['playbooks'] = repoTests['files']
                    } else {
                        // tmt
                        requestPayload['test']['fmf'] = repoUrlAndRef
                    }

                    def response = submitTestingFarmRequest(payloadMap: requestPayload)
                    testingFarmRequestId = response['id']
                }
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest())
            }
        }

        stage('Wait for Test Results') {
            when {
                expression { repoTests }
            }
            steps {
                script {
                    testingFarmResult = waitForTestingFarmResults(requestId: testingFarmRequestId, timeout: 60)
                    xunit = testingFarmResult.get('result', [:])?.get('xunit', '') ?: ''
                }
            }
        }

        stage('Process Test Results (XUnit)') {
            when {
                expression { xunit }
            }
            agent {
                kubernetes {
                    yaml podYAML
                    defaultContainer 'pipeline-agent'
                }
            }
            steps {
                script {
                    // Convert Testing Farm XUnit into JUnit and store the result in Jenkins
                    writeFile file: 'tfxunit.xml', text: "${xunit}"
                    sh script: "tfxunit2junit --docs-url ${pipelineMetadata['docs']} tfxunit.xml > xunit.xml"
                    junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'xunit.xml')
                }
            }
        }
    }

    post {
        always {
            evaluateTestingFarmResults(testingFarmResult)
        }
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, xunit: xunit, isSkipped: !hasTests, note: note, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testScenario: params.TEST_SCENARIO, xunit: xunit, dryRun: isPullRequest())
        }
    }
}
