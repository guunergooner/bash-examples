#!/bin/bash

function log () {
    echo $(date +"[%Y-%m-%d %H:%M:%S]") $@
}

function install-docker-ce () {
    log "begin install docker ce"

    docker-ce-repo="https://download.docker.com/linux/centos/docker-ce.repo"
    docker-ce-cli-package="docker-ce-cli-18.09.3-3.el7.x86_64"
    docker-ce-package="docker-ce-18.09.3-3.el7.x86_64"

    # Disable swap
    swapoff -a
    sed -i "s/\(^.*swap.*$\)/#\1/" /etc/fstab

    # Disable selinux
    sed -i "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config

    # Stop/Disable firewalld
    systemctl stop firewalld.service && systemctl disable firewalld.service

    # Stop/Disable iptables
    systemctl stop iptables.service && systemctl disable iptables.service

    # Remove old docker version
    docker=$(rpm -qa | grep docker- | xargs)
    [ -n "${docker}" ] && yum remove -y ${docker}

    # Update repo
    yum clean all && yum update

    # Install Docker CE
    ## Set up the repository
    ### Install required packages.
    yum install -y yum-utils device-mapper-persistent-data lvm2

    ### Add docker repository.
    yum-config-manager \
            --add-repo \
            ${docker-ce-repo}

    ## Install docker ce.
    yum install -y ${docker-ce-cli-package} ${docker-ce-package}

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
      "Hard" : 2048,
      "Soft" : 1024
    },
    "nproc" : {
      "Name" : "nproc",
      "Hard" : 2048,
      "Soft" : 1024
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
