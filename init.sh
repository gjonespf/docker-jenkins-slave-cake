#!/bin/bash

if [ -z "$JENKINS_HOMEDIR" ]
then
  JENKINS_HOMEDIR=/home/jenkins/
fi

if [ -n "$IDENC" ]
then
  ID=$(echo $IDENC |base64 -d)
  IDPUB=$(echo $IDPUBENC |base64 -d)
fi

if [ -n "$ID" ]
then
  echo "Adding SSH Keys to agent"
  mkdir $JENKINS_HOMEDIR/.ssh
  echo "$ID"   > $JENKINS_HOMEDIR/.ssh/id_rsa_jenkins
  echo "$IDPUB" > $JENKINS_HOMEDIR/.ssh/id_rsa_jenkins.pub

  eval "$(ssh-agent -s)"
  chmod 600 -R $JENKINS_HOMEDIR/.ssh/id_rsa_jenkins
  ssh-add $JENKINS_HOMEDIR/.ssh/id_rsa_jenkins
  echo -e "StrictHostKeyChecking no\nUserKnownHostsFile=/dev/null" > $JENKINS_HOMEDIR/.ssh/config
  echo -e "Host jenkins\n\tIdentityFile $JENKINS_HOMEDIR/.ssh/id_rsa_jenkins" >> $JENKINS_HOMEDIR/.ssh/config
fi

/scripts/jenkins-user-setup.sh

echo -e "$(date) starting jenkins-slave. found these env vars: \nIDPUB:$IDPUB"

if [ -n "$1" ]
then
  gosu jenkins $1
else
  # Gosu
  # gosu jenkins sudo 
  /usr/sbin/sshd -D
fi
