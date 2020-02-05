#!/bin/bash
minikube start --vm-driver=vmware \
  --cpus=8 \
  --memory=12280 \
  --disk-size=64g \
  --mount-string="$HOME/data:/data"
