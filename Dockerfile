FROM gavinjonespf/docker-toolbox:latest
ENV TERM xterm

ARG apt_proxy
RUN if [ "${apt_proxy}" != "" ]; then echo "Acquire::http { Proxy \"${apt_proxy}\"; };" > /etc/apt/apt.conf.d/01proxy; cat /etc/apt/apt.conf.d/01proxy; fi; 

#Tools from 
# https://hub.docker.com/r/evarga/jenkins-slave/
RUN apt-get -q update && apt-get install -y locales sudo &&\
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
# Should be in toolbox
# RUN apt-get -q update &&\
#     DEBIAN_FRONTEND="noninteractive" apt-get -y install mono-devel &&\
#     apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin

#No longer working/required
#RUN mozroots --import --sync
#RUN cert-sync /etc/ssl/certs/ca-certificates.crt

# This includes mono bits, useful for compiling
# RUN yes | certmgr -ssl -m https://go.microsoft.com \
# 	&& yes | certmgr -ssl -m https://nugetgallery.blob.core.windows.net \
# 	&& yes | certmgr -ssl -m https://nuget.org 
    
# Nuget install
# Now on toolbox
# TODO: tzdata needed for SSL to work, should probably be in base image also?
# RUN apt-get -q update &&\
#     DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata nuget unzip &&\
#     apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin

# Docker user setup, doesn't seem to work correctly
#RUN     addgroup docker && usermod -a -G docker jenkins
#adduser jenkins docker

# DotNet Core install
# PowerShell Core install
# ENV				DOTNET_PACKAGE dotnet-dev-1.0.4
# ENV 			POWERSHELL_DOWNLOAD_URL https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-beta.2/powershell_6.0.0-beta.2-1ubuntu1.16.04.1_amd64.deb
# Done as part of toolbox

#Any general tools
WORKDIR /home/jenkins/tools/
COPY    tools/packages.config packages.config
RUN     nuget install

#Gitversion
RUN     mkdir -p /usr/lib/GitVersion/
COPY    scripts/rungitversion.sh /usr/lib/GitVersion/rungitversion.sh
RUN     mv /home/jenkins/tools/GitVersion.CommandLine*/tools/* /usr/lib/GitVersion/ \
        && sed -i 's|lib/linux/x86_64|/usr/lib/GitVersion/lib/linux/x86_64|g' /usr/lib/GitVersion/LibGit2Sharp.dll.config \
        && chmod a+x /usr/lib/GitVersion/rungitversion.sh \
        && ln -s /usr/lib/GitVersion/rungitversion.sh /usr/sbin/gitversion

# Cake install
#curl -Lsfo "$NUGET_EXE" https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
#RUN curl -Lsfo build.sh http://cakebuild.net/download/bootstrapper/linux && chmod a+x build.sh && ./build.sh
# 
WORKDIR /usr/lib/cake
COPY    scripts/runcake.sh runcake.sh
RUN mkdir -p /usr/lib/cake/ \
    && curl -Lsfo "/usr/lib/cake/packages.config" http://cakebuild.net/download/bootstrapper/packages \
    && cd /usr/lib/cake \
    && nuget install -ExcludeVersion \
    && chmod a+x /usr/lib/cake/runcake.sh \
    && ln -s /usr/lib/cake/runcake.sh /usr/sbin/cake

# Pull PS modules as required
RUN     nuget sources add -name "PSGallery" -Source "https://www.powershellgallery.com/api/v2/" \
        && mkdir -p /home/jenkins/.local/share/powershell/Modules
COPY    ./PSModules/packages.config /home/jenkins/.local/share/powershell/Modules/
RUN     cd /home/jenkins/.local/share/powershell/Modules/ && nuget install -ExcludeVersion

#GOSU instead
ARG GOSU_VERSION=1.10
RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture)" \
    && chmod +x /usr/local/bin/gosu

COPY ./init.sh /scripts/init.sh
RUN chmod 777 /scripts/init.sh
COPY ./jenkins-user-setup.sh /scripts/jenkins-user-setup.sh
RUN chmod 777 /scripts/jenkins-user-setup.sh
# Need to use gosu instead...
#TODO: Remove sudo?
#USER jenkins
#RUN touch ~/.sudo_as_admin_successful
WORKDIR /home/jenkins
EXPOSE 22
CMD [ "/scripts/init.sh" ]

