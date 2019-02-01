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
    apt-get -q autoremove -y &&\
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

# Cake install - todo replace with dotnet tool instead
WORKDIR /usr/lib/cake
COPY    scripts/runcake.sh /usr/lib/cake/runcake.sh
RUN mkdir -p /usr/lib/cake/ \
    && curl -Lsfo "/usr/lib/cake/packages.config" http://cakebuild.net/download/bootstrapper/packages \
    && cd /usr/lib/cake \
    && nuget install -ExcludeVersion \
    && chmod a+x /usr/lib/cake/runcake.sh \
    && ln -s /usr/lib/cake/runcake.sh /usr/sbin/cake

# Pull PS modules as required
RUN     nuget sources add -name "PSGallery" -Source "https://www.powershellgallery.com/api/v2/" \
        && mkdir -p /home/jenkins/.local/share/powershell/Modules

# TZ Setup required for HTTPS to work correctly...
# gss-ntlmssp to ensure kerberos NTLM works
RUN apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata gss-ntlmssp &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin
ENV TZ=Etc/GMT
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Update to latest dotnet and pwsh, including libcurl due to SSL issues otherwise
# libcurl3 - Needed for?
# libcurl4
RUN apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -y upgrade dotnet-host dotnet-sdk-2.2 powershell &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin

#GOSU instead
ARG GOSU_VERSION=1.10
RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture)" \
    && chmod +x /usr/local/bin/gosu

COPY scripts/init.sh /scripts/init.sh
RUN chmod 777 /scripts/init.sh
COPY scripts/jenkins-user-setup.sh /scripts/jenkins-user-setup.sh
RUN chmod 777 /scripts/jenkins-user-setup.sh
COPY scripts/runbootstrap.sh /scripts/runbootstrap.sh
RUN chmod 777 /scripts/runbootstrap.sh

# Need to use gosu instead...
#TODO: Remove sudo and go back to Jenkins user...
#USER jenkins
#RUN touch ~/.sudo_as_admin_successful
WORKDIR /home/jenkins
# Alias missing from new versions
RUN echo 'alias powershell="pwsh"' >> /home/jenkins/.bashrc && chown 1000:1000 /home/jenkins/.bashrc
RUN echo '#!/bin/bash\n/usr/bin/pwsh $*' > /usr/bin/powershell && \
    chmod +x /usr/bin/powershell
RUN echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> /home/jenkins/.bashrc && chown 1000:1000 /home/jenkins/.bashrc

# Install dotnet build tools
# https://www.nuget.org/packages/Octopus.DotNet.Cli/
RUN dotnet tool install Octopus.DotNet.Cli --tool-path /home/jenkins/.dotnet/tools/
# https://www.nuget.org/packages/Cake.Tool/
RUN dotnet tool install Cake.tool --tool-path /home/jenkins/.dotnet/tools/
# https://www.nuget.org/packages/GitVersion.Tool/
RUN dotnet tool install Gitversion.Tool --version 4.0.1-beta1-59 --tool-path /home/jenkins/.dotnet/tools/
RUN apt-get -q update && apt-get install -y libgit2-dev && apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin && apt-get -q autoremove -y
RUN chown -R jenkins:jenkins /home/jenkins/ && chown -R jenkins:jenkins /home/jenkins/.local/
RUN mkdir -p /home/jenkins/init/ && chown 1000:1000 /home/jenkins/init/
COPY scripts/init/*.sh /home/jenkins/init/
RUN chmod a+x /home/jenkins/init/*.sh
RUN chown 1000:1000 /home/jenkins/init/*.sh

# Clean up
RUN apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin && apt-get -q autoremove -y

EXPOSE 22
CMD [ "/scripts/init.sh" ]

