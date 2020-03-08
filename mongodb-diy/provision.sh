#!/bin/bash
kubectl create ns mongodb
kubectl -n mongodb create secret generic mongodb-admin-creds --from-literal=username=main_user --from-literal=password=CHANGEME
kubectl -n mongodb apply -f mongodb-storageclass.yml
kubectl -n mongodb apply -f mongodb-persistent-volume.yml
kubectl -n mongodb apply -f mongodb-statefulset.yml
kubectl -n mongodb apply -f mongodb-nodeport.yml
