#!/bin/bash
# Create mongodb namespace in K8s
kubectl create namespace mongodb
# Download Custom Resource Definitions (crds.yaml is in .gitignore)
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
kubectl apply -f crds.yaml
# Download MongoDB Enterprise Operator (mongodb-enterprise.yaml is in .gitignore)
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
kubectl apply -f mongodb-enterprise.yaml
# Create creds for Ops Manager admin
kubectl create secret generic ops-manager-admin-secret \
  --from-literal=Username="admin@opsmanager.com" \
  --from-literal=Password="Passw0rd." \
  --from-literal=FirstName="Ops" \
  --from-literal=LastName="Manager" \
  -n mongodb
# Deploy Ops Manager on K8s
kubectl apply -f mongodb-ops-manager.yml
# wait a few mins for the objects to create (5-10 mins, yeah I know))
kubectl -n mongodb get om -w
