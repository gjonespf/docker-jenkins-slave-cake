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

    stages {
        stage('Init') {
            steps {
                echo 'Initializing...'
                executeXplat "powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Init\"\""
            }
        }
        stage('Build') {
            steps {
                echo "Running #${env.BUILD_ID} on ${env.JENKINS_URL}"
                executeXplat 'Building...'
                bat "powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Build\"\""
            }
        }
        stage('Package') {
            steps {
                echo 'Packaging...'
                executeXplat "powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Package\"\""
            }
        }
        stage('Test'){
            steps {
                echo 'Testing...'
                executeXplat "powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Test\"\""
            }
        }
        stage('Publish') {
            steps {
                echo 'Publishing...'
                executeXplat "powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Publish\"\""
            }
        }
    }

    
    post {
        always {
            archiveArtifacts artifacts: '**/.buildenv/$BUILD_ID/**', fingerprint: true
        }
    }
}