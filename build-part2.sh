#!/bin/bash
kubectl create secret generic om-main-user-credentials \
  --from-literal="user=admin@opsmanager.com" \
  --from-literal="publicApiKey=687242dd-d524-41b7-97db-e16987e6888d" \
  -n mongodb

kubectl create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb

kubectl -n mongodb apply -f mongodb-m2-shardedcluster.yml
kubectl -n mongodb apply -f mongodb-m2-loadbalancer.yml
