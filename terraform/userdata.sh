#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/clinic-userdata.log) 2>&1

apt-get update -y

apt-get install -y \
  docker.io \
  git \
  curl \
  unzip \
  ca-certificates

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

KUBECTL_VERSION="v1.31.0"

curl -Lo /tmp/kubectl \
  "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

install -o root -g root -m 0755 \
  /tmp/kubectl \
  /usr/local/bin/kubectl

KIND_VERSION="v0.24.0"

curl -Lo /tmp/kind \
  "https://kind.sigs.k8s.io/dl/$${KIND_VERSION}/kind-linux-amd64"

install -o root -g root -m 0755 \
  /tmp/kind \
  /usr/local/bin/kind

rm -rf /home/ubuntu/clo835-project

git clone "${github_repo}" /home/ubuntu/clo835-project

chown -R ubuntu:ubuntu /home/ubuntu/clo835-project

chmod +x /home/ubuntu/clo835-project/bootstrap.sh

if [ -f /home/ubuntu/clo835-project/verify-clinic.sh ]; then
  chmod +x /home/ubuntu/clo835-project/verify-clinic.sh
fi

touch /home/ubuntu/USERDATA-COMPLETE
chown ubuntu:ubuntu /home/ubuntu/USERDATA-COMPLETE