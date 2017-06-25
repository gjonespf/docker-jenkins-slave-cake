FROM gavinjonespf/docker-toolbox:latest
ENV TERM xterm

ARG apt_proxy
RUN if [ "${apt_proxy}" != "" ]; then echo "Acquire::http { Proxy \"${apt_proxy}\"; };" > /etc/apt/apt.conf.d/01proxy; fi; cat /etc/apt/apt.conf.d/01proxy

#Tools from 
# https://hub.docker.com/r/evarga/jenkins-slave/
RUN apt-get install -y locales &&\
    locale-gen en_US.UTF-8 &&\
    apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends openssh-server &&\
    apt-get -q autoremove &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin &&\
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd &&\
    mkdir -p /var/run/sshd

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install JDK 8 (latest edition)
RUN apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends software-properties-common &&\
    add-apt-repository -y ppa:openjdk-r/ppa &&\
    apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends openjdk-8-jre-headless &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin

# Set user jenkins to the image
RUN useradd -m -d /home/jenkins -s /bin/sh jenkins &&\
    echo "jenkins:jenkins" | chpasswd

# Jenkins requires SSH and other tools 
RUN apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get install -y openssh-server git curl &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin
    
# Mono required for a bunch of things
RUN apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -y install mono-devel &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin

#No longer working/required
#RUN mozroots --import --sync
RUN cert-sync /etc/ssl/certs/ca-certificates.crt

# Nuget install
RUN	apt-get install -y nuget
# This includes mono bits, useful for compiling
RUN yes | certmgr -ssl -m https://go.microsoft.com \
	&& yes | certmgr -ssl -m https://nugetgallery.blob.core.windows.net \
	&& yes | certmgr -ssl -m https://nuget.org 

# DotNet Core install
# PowerShell Core install
# As part of toolbox

# Cake install
#RUN curl -Lsfo build.sh http://cakebuild.net/download/bootstrapper/linux && chmod a+x build.sh && ./build.sh

# Pull PS modules as required

COPY ./init.sh /scripts/init.sh
RUN chmod 777 /scripts/init.sh
USER jenkins
RUN touch ~/.sudo_as_admin_successful
WORKDIR /home/jenkins




EXPOSE 22
CMD [ "/scripts/init.sh" ]
#CMD ["sudo", "/usr/sbin/sshd", "-D"]


# testing
# docker pull jumanjiman/dotnet:latest
# docker run --rm -it jumanjiman/dotnet:latest bash