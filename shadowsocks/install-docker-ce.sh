#!/bin/bash

function log () {
    echo $(date +"[%Y-%m-%d %H:%M:%S]") $@
}

function install-docker-ce () {
    log "begin install docker ce"

    docker_ce_repo="https://download.docker.com/linux/centos/docker-ce.repo"
    docker_ce_cli_package="docker-ce-cli-18.09.3-3.el7.x86_64"
    docker_ce_package="docker-ce-18.09.3-3.el7.x86_64"

    # Disable swap
    swapoff -a
    sed -i "s/\(^.*swap.*$\)/#\1/" /etc/fstab

    # Disable selinux
    sed -i "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config

    # Remove old docker version
    docker=$(rpm -qa | grep docker- | xargs)
    [ -n "${docker}" ] && yum remove -y ${docker}

    # Update repo
    yum clean all && yum update -y

    # Install Docker CE
    ## Set up the repository
    ### Install required packages.
    yum install -y yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        wget \
        curl \
        net-tools \
        iputils \
        vim

    ### Add docker repository.
    yum-config-manager \
            --add-repo \
            ${docker_ce_repo}

    ## Install docker ce.
    yum install -y ${docker_ce_cli_package} ${docker_ce_package}

    ## Create /etc/docker directory.
    [ ! -d /etc/docker ] && mkdir /etc/docker

    # Setup daemon.
    cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile" : {
      "Name" : "nofile",
      "Hard" : 65536,
      "Soft" : 65536
    },
    "nproc" : {
      "Name" : "nproc",
      "Hard" : 65536,
      "Soft" : 65536
    },
    "core" : {
      "Name" : "core",
      "Hard" : 0,
      "Soft" : 0
    }
  }
}
EOF

    # Restart docker.
    systemctl daemon-reload
    systemctl enable docker.service && systemctl start docker.service
    systemctl status docker.service

    log "end install docker ce"
}

install-docker-ce
