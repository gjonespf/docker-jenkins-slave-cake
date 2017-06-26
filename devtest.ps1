
docker run --rm -it -v ${pwd}:/mnt/build -v /var/run/docker.sock:/var/run/docker.sock:ro  gjonespf/docker-jenkins-slave-cake /scripts/init.sh powershell
