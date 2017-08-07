#!/usr/bin/groovy

pipeline {
    agent { label 'linux-cake' } 

    stages {
        stage('Init') {
            steps {
                echo 'Initializing...'
                sh ("powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Init\"\"")
            }
        }
        stage('Build') {
            steps {
                echo "Running #${env.BUILD_ID} on ${env.JENKINS_URL}"
                echo 'Building...'
                sh ("powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Build\"\"")
            }
        }
        stage('Package') {
            steps {
                echo 'Packaging...'
                sh ("powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Package\"\"")
            }
        }
        stage('Test'){
            steps {
                echo 'Testing...'
                sh ("powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Test\"\"")
            }
        }
        stage('Publish') {
            steps {
                echo 'Publishing...'
                sh ("powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command \"& '.\\build.ps1' -Target \"Publish\"\"")
            }
        }
    }
}