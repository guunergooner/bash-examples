#!/bin/bash

echo $#
echo $*

set +e

function log () {
    echo $(date +"[%Y-%m-%d %H:%M:%S]") $@
}

if [ $# -ne 2 ]; then
    log "Usage: bash $(basename $0) port passwd"
    exit
fi

port=$1
passwd=$2

port=${port:-"40000"}
passwd=${passwd:-"gooner@12345"}
container_name=${container_name:-"shadowsocks"}

docker pull oddrationale/docker-shadowsocks

docker rm -f ${container_name}

docker run -d -p ${port}:${port} --name ${container_name} \
    oddrationale/docker-shadowsocks \
    -s 0.0.0.0 -p ${port} -k ${passwd} -m aes-256-cfb
