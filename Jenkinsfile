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
        CC = 'clang'
    }

    stages {
        stage('Init') {
            steps
            {
                echo 'Initializing...'
                script {
                    if (isUnix()) {
                        echo 'Running on Unix...'
                        sh "./build.sh -t \"Init\"" 
                    } else  {
                        echo 'Running on Windows...'
                        bat "powershell -ExecutionPolicy Bypass -Command \"& './build.ps1' -Target \"Init\"\""
                    }
                }
            }
        }
        stage('Build') {
            steps {
                echo "Running #${env.BUILD_ID} on ${env.JENKINS_URL}"
                echo 'Building...'
                script {
                    if (isUnix()) {
                        sh "./build.sh -t \"Build\"" 
                    } else  {
                        bat "powershell -ExecutionPolicy Bypass -Command \"& './build.ps1' -Target \"Build\"\""
                    }
                }
            }
        }
        stage('Package') {
            steps {
                echo 'Packaging...'
                script {
                    if (isUnix()) {
                        sh "./build.sh -t \"Package\"" 
                    } else  {
                        bat "powershell -ExecutionPolicy Bypass -Command \"& './build.ps1' -Target \"Package\"\""
                    }
                }
            }
        }
        stage('Test'){
            steps {
                echo 'Testing...'
                script {
                    if (isUnix()) {
                        sh "./build.sh -t \"Test\"" 
                    } else  {
                        bat "powershell -ExecutionPolicy Bypass -Command \"& './build.ps1' -Target \"Test\"\""
                    }
                }
            }
        }
        stage('Publish') {
            steps {
                echo 'Publishing...'
                script {
                    if (isUnix()) {
                        sh "./build.sh -t \"Publish\"" 
                    } else  {
                        bat "powershell -ExecutionPolicy Bypass -Command \"& './build.ps1' -Target \"Publish\"\""
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/.buildenv/$BUILD_ID/**', fingerprint: true
        }
    }
}