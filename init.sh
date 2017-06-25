#!/bin/sh

if [ -n "$IDENC" ]
then
  ID=$(echo $IDENC |base64 -d)
  IDPUB=$(echo $IDPUBENC |base64 -d)
fi

if [ -n "$ID" ]
then
  echo "Adding SSH Keys to agent"
  mkdir ~/.ssh
  echo "$ID"   > ~/.ssh/id_rsa_jenkins
  echo "$IDPUB" > ~/.ssh/id_rsa_jenkins.pub

  eval "$(ssh-agent -s)"
  chmod 600 -R ~/.ssh/id_rsa_jenkins
  ssh-add ~/.ssh/id_rsa_jenkins
  echo -e "StrictHostKeyChecking no\nUserKnownHostsFile=/dev/null" > ~/.ssh/config
  echo -e "Host jenkins\n\tIdentityFile ~/.ssh/id_rsa_jenkins" >> ~/.ssh/config
fi
echo -e "$(date) starting jenkins-slave. found these env vars: \nIDPUB:$IDPUB"

sudo /usr/sbin/sshd -D
