#!/bin/bash
minikube start --vm-driver=virtualbox \
  --cpus=4 \
  --memory=10240 \
  --disk-size=64g \
  --mount-string="$HOME/data:/data" \
  --kubernetes-version=1.15.10
