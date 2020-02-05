#!/bin/bash
kubectl create namespace mongodb
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
kubectl apply -f crds.yaml
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
kubectl apply -f mongodb-enterprise.yaml
kubectl create secret generic ops-manager-admin-secret \
  --from-literal=Username="opsman.admin@mongodb.com" \
  --from-literal=Password="Passw0rd." \
  --from-literal=FirstName="Ops" \
  --from-literal=LastName="Manager" \
  -n mongodb
kubectl apply -f mongodb-ops-manager-1.yml
kubectl -n mongodb get om -w
