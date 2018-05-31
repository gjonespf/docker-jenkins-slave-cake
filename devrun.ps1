#!/usr/bin/pwsh

# docker run --rm -it -v ${pwd}:/mnt/build -v /var/run/docker.sock:/var/run/docker.sock:ro -v bootstrap-test.sh:/home/jenkins/init/bootstrap-test.sh  gavinjonespf/docker-jenkins-slave-cake /bin/bash

docker run --rm -it -v ${pwd}:/mnt/build -v /var/run/docker.sock:/var/run/docker.sock:ro -v bootstrap-test.sh:/home/jenkins/init/bootstrap-test.sh  gavinjonespf/docker-jenkins-slave-cake /scripts/init.sh
