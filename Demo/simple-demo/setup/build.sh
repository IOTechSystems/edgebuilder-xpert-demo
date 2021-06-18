#!/bin/sh

set -ex

UNAME=`uname -m`
case $UNAME in
  arm*)
    ARCH=arm
  ;;
  aarch64)
    ARCH=arm64
  ;;
  x86_64)
    ARCH=x86_64
  ;;
  *)
    echo "Unsupported: architecture $UNAME"
    exit 2
  ;;
esac

ARCHIVE=$1
DIMAGE=${2-iotechsys/edgexpert-demo-lua}
VER=${VERSION:-metadata-setup}
DFILE=Dockerfile

docker rmi -f ${DIMAGE}:${VER}-${ARCH}
docker build -f ${DFILE} --tag ${DIMAGE}:${VER}-${ARCH} .
if [ "$ARCHIVE" = "true" ]; then
  docker push ${DIMAGE}:${VER}-${ARCH}
fi
