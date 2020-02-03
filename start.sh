#!/bin/bash
minikube start --vm-driver=vmware \
  --cpus=4 \
  --memory=8192 \
  --disk-size=64g \
  --mount-string="$HOME/data:/data"
