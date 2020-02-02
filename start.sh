#!/bin/bash
minikube start --vm-driver=vmware \
  --cpus=12 \
  --memory=8192 \
  --disk-size=64g \
  --mount-string="$HOME/data:/data"
