#!/bin/bash
kubectl -n mongodb delete service mongodb-nodeport
kubectl -n mongodb delete statefulset mongodb-standalone
kubectl -n mongodb delete persistentvolumeclaim mongodb-standalone
kubectl -n mongodb delete persistentvolume mongodb-standalone
kubectl -n mongodb delete storageclass mongodb-standalone
kubectl -n mongodb delete secret mongodb-admin-creds
kubectl delete ns mongodb
