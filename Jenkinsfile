#!/usr/bin/groovy
def executeXplat(commandString) {
    if (isUnix()) {
        sh commandString
    } else {
        bat commandString
    }
}

pipeline {
    agent { label 'xplat-cake' } 
    environment { 
        GITCREDENTIALSID = '37111da6-83b4-4563-930e-b586035264be'
    }

    stages {
        stage('Pre') {
            steps {
                echo "Using proxy: ${env.HTTP_PROXY}"
                
                withCredentials([
                    usernamePassword(credentialsId: '37111da6-83b4-4563-930e-b586035264be', passwordVariable: 'GITKEY', usernameVariable: 'GITUSER')
                ])
                {
                    echo 'Preparing...'
                    executeXplat "pwsh -NonInteractive -NoProfile -ExecutionPolicy Bypass ./pre.ps1 "
                }
            }
        }
        stage('Init') {
            steps {
                echo 'Initializing...'
                executeXplat "pwsh -NonInteractive -NoProfile -ExecutionPolicy Bypass ./build.ps1 -Target \"Init\" "
            }
        }
        stage('Build') {
            steps {
                echo "Running #${env.BUILD_ID} on ${env.JENKINS_URL}"
                echo 'Building...'
                executeXplat "pwsh -NonInteractive -NoProfile -ExecutionPolicy Bypass ./build.ps1 -Target \"Build\" "
            }
        }
        stage('Package') {
            steps {
                echo 'Packaging...'
                executeXplat "pwsh -NonInteractive -NoProfile -ExecutionPolicy Bypass ./build.ps1 -Target \"Package\" "
            }
        }
        stage('Test'){
            steps {
                echo 'Testing...'
                executeXplat "pwsh -NonInteractive -NoProfile -ExecutionPolicy Bypass ./build.ps1 -Target \"Test\" "
            }
        }
        stage('Publish') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'e162c9e0-0792-472d-a01e-51f2b7427f2b', passwordVariable: 'OCTOAPIKEY', usernameVariable: 'OCTOSERVER'),
                    usernamePassword(credentialsId: '74207640-6946-44f4-8175-171e9d807193', passwordVariable: 'OCTOCLOUDAPIKEY', usernameVariable: 'OCTOCLOUDSERVER'),
                    usernamePassword(credentialsId: '74d7f630-d422-4324-89f2-6ebccc3b3687', passwordVariable: 'LocalNugetApiKey', usernameVariable: 'LocalNugetServerUrl'),
                    usernamePassword(credentialsId: '74a39230-d94d-4660-b686-daf40f89e462', passwordVariable: 'LocalChocolateyApiKey', usernameVariable: 'LocalChocolateyServerUrl')
                    ]) 
                {
                    echo 'Publishing...'
                    executeXplat "pwsh -NonInteractive -NoProfile -ExecutionPolicy Bypass ./build.ps1 -Target \"Publish\" "
                }
            }
        }
        // TODO: Update release deets?
    }

    post {
        success {
            archiveArtifacts allowEmptyArchive: true, artifacts: 'BuildArtifacts/**', fingerprint: true
        }
    }
}

