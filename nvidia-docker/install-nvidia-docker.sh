#!/bin/bash

function log () {
    echo $(date +"[%Y-%m-%d %H:%M:%S]") $@
}

function install-nvidia-docker () {
    # Update repo
    yum install -y kernel-devel epel-release
    yum install -y freeglut-devel libX11-devel libXi-devel libXmu-devel mesa-libGLU-devel
    yum install -y dkms lshw

    # Identify graphic card
    if [ -n "$(lshw -numeric -C display | grep driver=nouveau | uniq)" ]; then
        GRUB_CMDLINE_LINUX=$(grep GRUB_CMDLINE_LINUX /etc/default/grub | cut -d '=' -f2- | tr -d '"')
        sed -i "s/$GRUB_CMDLINE_LINUX/$GRUB_CMDLINE_LINUX nouveau.modeset=0/g" /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi

    # Install nvidia-driver and CUDA Toolkit
    CUDA_TOOLKIT=cuda_10.1.105_418.39_linux.run
    wget --no-check-certificate -c https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/${CUDA_TOOLKIT} \
        -O ${CUDA_TOOLKIT}
    chmod +x ${CUDA_TOOLKIT}
    bash ${CUDA_TOOLKIT}

    cat <<EOF >> /etc/ld.so.conf
#add by $(whoami) $(date +%Y-%m-%d)
/usr/local/cuda-10.1/lib64
EOF
    ldconfig

    cat <<EOF >> $HOME/.bashrc
#add by $(whoami) $(date +%Y-%m-%d)
PATH=/usr/local/cuda/bin:\$PATH
EOF
    source $HOME/.bashrc
    nvcc --version
    nvidia-persistenced --persistence-mode
    nvidia-smi

    # Add the package repositories
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | \
      tee /etc/yum.repos.d/nvidia-docker.repo

    # Install nvidia-docker2 and reload the Docker daemon configuration
    yum install -y nvidia-container-runtime-2.0.0-1.docker18.09.3.x86_64
    yum install -y nvidia-docker2-2.0.3-1.docker18.09.3.ce.noarch

    cat > /etc/docker/daemon.json <<EOF
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "/usr/bin/nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "insecure-registries": [
    "harbor.com"
  ],
  "experimental": true,
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

    # Important: restart docker
    pkill -SIGHUP dockerd
    systemctl restart docker.service
    # Test nvidia-smi with the latest official CUDA image
    docker run --runtime=nvidia --rm nvidia/cuda:10.0-base nvidia-smi
}
