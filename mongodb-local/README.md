# MongoDB on K8s - Minikube

This document describes how to demo the [MongoDB Enterprise Kubernetes Operator](https://docs.mongodb.com/kubernetes-operator/master/) to stamp out MongoDB instances on your MacBook using [Minikube](https://minikube.sigs.k8s.io/).

_The demo environment runs on Minikube and can be taxing to a MacBook, as such it's recommended to shutdown non-essentials for the best experience (close those Chrome tabs?)._ 🤔

_It also might be good to consider using [VMware Fusion](https://www.vmware.com/products/fusion/fusion-evaluation.html) over VirtualBox which will improve your experience running VMs locally._

## TOC

* [Install Required Infra](#install-required-infra)
* [Deploy Operator](#deploy-operator)
* [Deploy MongoDB Ops Manager](#deploy-mongodb-ops-manager)
* [Connect Operator with Ops Manager](#connect-operator-with-ops-manager)
* [Deploy MongoDB with the Operator](#deploy-mongodb-with-the-operator)
* [Teardown](#teardown)
* [Downloads](#downloads)
* [References](#references)

## Install Required Infra

Install the following tools on your MacBook.  There's several ways to install and setup each of these so pick a method that works for you.  Install options are documented in the links below.

* [VirtualBox v6.x](https://www.virtualbox.org/wiki/Downloads) - Required for virtualization substrate
* [Minikube v1.6+](https://minikube.sigs.k8s.io/docs/start/) - VM running Kubernetes
* [Kubectl v1.15.x](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for interacting with Kubernetes
* [MongoDB Enterprise v4.2.x](https://www.mongodb.com/download-center/enterprise) - Installed locally for mongo client

You should be able to resolve each from the command line.

```bash
# virtualbox version
$ vboxmanage --version
6.1.2r135662

$ minikube version
minikube version: v1.6.2

$ kubectl version -o json
{
  "clientVersion": {
    "major": "1",
    "minor": "15",
    "gitVersion": "v1.15.0",
    "gitCommit": "e8462b5b5dc2584fdcd18e6bcfe9f1e4d970a529",
    "gitTreeState": "clean",
    "buildDate": "2019-06-19T16:40:16Z",
    "goVersion": "go1.12.5",
    "compiler": "gc",
    "platform": "darwin/amd64"
  }
}

$ mongo --version
MongoDB shell version v4.2.3
```

## Deploy Operator

* [Configure and Start Minikube](#configure-and-start-minikube)
* [Create mongodb namespace](#create-mongodb-namespace)
* [Apply MongoDB Custom Resource Definitions](#apply-mongodb-custom-resource-definitions)
* [Deploy MongoDB Operator](#deploy-mongodb-operator)

### Configure and Start Minikube

For the best experience you'll need at least 8 GB to 10 GB of ram allocated to Minikube. Give as much as you can for both CPU and Memory!

```bash
# start.sh
# use --vm-driver=vmware if you have VMware Fusion installed
minikube start --vm-driver=virtualbox \
  --cpus=4 \
  --memory=10240 \
  --disk-size=32g \
  --mount-string="$HOME/data:/data" \
  --kubernetes-version=1.15.10  
```

### Create mongodb namespace

All our K8s objects will be deployed into this namespace.

```bash
kubectl create namespace mongodb
```

### Apply MongoDB Custom Resource Definitions

[Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) are a way to extend the K8s API and the MongoDB Operator uses these CRDs to define the following MongoDB objects.

* [MongoDB](https://docs.mongodb.com/kubernetes-operator/stable/reference/k8s-operator-specification/) - K8s resource for MongoDB objects such as Standalone, ReplicaSet and ShardedClusters
* MongoDBUser - K8s resource for MongoDB users
* [MongoDBOpsManager](https://docs.mongodb.com/kubernetes-operator/stable/reference/k8s-operator-om-specification/) - K8s resource for MongoDB Enterprise Ops Manager

```bash
# Download Custom Resource Definitions
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
kubectl apply -f crds.yaml
```

### Deploy MongoDB Operator

Once CRDs are loaded apply the MongoDB Operator to create service accounts and the actual Operator in our K8s cluster.

```bash
# Download MongoDB Enterprise Operator
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
kubectl apply -f mongodb-enterprise.yaml
# View the Operator deployment
kubectl -n mongodb describe deployment mongodb-enterprise-operator
kubectl -n mongodb get deployment mongodb-enterprise-operator
```

At this point the Operator deployment is running and we can now use it to deploy MongoDB Ops Manager.

## Deploy MongoDB Ops Manager

**Note:** Deploying Ops Manager with the Operator is currently in beta (03/01/2020) but we're doing so because having everything run in K8s is a bit convenient and cool. :sunglasses:

* [Configure Ops Manager Deployment](#configure-ops-manager-deployment)
* [Deploy Ops Manager](#deploy-ops-manager)
* [Setup Ops Manager](#setup-ops-manager)
* [Cleanup Ops Manager admin Secret](#cleanup-ops-manager-admin-secret)

### Configure Ops Manager Deployment

Create Ops Manager credentials as a K8s Secret so we can login to the Ops Manager UI once its running. :running:

```bash
kubectl create secret generic ops-manager-admin-secret \
--from-literal=Username="admin@opsmanager.com" \
--from-literal=Password="Passw0rd." \
--from-literal=FirstName="Ops" \
--from-literal=LastName="Manager" \
-n mongodb
```

### Deploy Ops Manager

In this section, we will deploy MongoDB Ops Manager in a Pod as well as a 3 member MongoDB Replica Set for the Ops Manager Database. 

Download the MongoDB Ops Manager configuration file from [here](./mongodb-ops-manager.yml) in the repo (or use the curl command in the script below).

**Note:** The yaml file specifies that NodePort will be used for external connectivity, and that backup is disabled - these are not best practices, but recommended given we're running on Minikube and resources are precious.

First, download the configuration file from the repo (if you didn't download it manually above):

```bash
curl -O https://raw.githubusercontent.com/corbtastik/mongodb-on-k8s/master/mongodb-local/mongodb-ops-manager.yml
```

Now, apply the configuration using the following command: 

```bash
kubectl apply -f mongodb-ops-manager.yml
```

**Note:** Startup time will vary based on Hardware and quota given to Minikube, however expect to wait at least 5-10 mins for everything to reach Running status.

To monitor progress by using the following command (note: it will take at least 5-10 minutes to complete):

```bash
kubectl -n mongodb get om -w
```

Once the deployment is complete, you can run the following command and validate the output against what's shown below to confirm that it has executed successfully:

```bash
kubectl -n mongodb get pods -o wide  

NAME                        READY  STATUS             RESTARTS  AGE
mongodb-enterprise-operator 1/1    Running            0         62m
ops-manager-0               1/1    Running            0         7m3s
ops-manager-db-0            1/1    Running            0         9m20s
ops-manager-db-1            1/1    Running            0         8m24s
ops-manager-db-2            1/1    Running            0         7m48s
```

### Setup Ops Manager

Next we will opne Ops Manager in our browser in order to complete the Ops Manager setup. In order to do that, we need the IP/Port that map to the Ops Manager Pod. 

In order to find that, you need to find the IP address for the Kubernetes master node, and the port which maps onto the Ops Manager Service. 

You can get these by executing the following commands:
```bash
# Kubernetes Master IP
minikube ip

# Port mapped to MongoDB Ops Manager service (should be something like 3xxxx)
kubectl -n mongodb get service ops-manager-svc-ext
```

Open MongoDB Ops Manager at in your browser at ``http://MASTER-IP:NODE-PORT`` and login with the `ops-manager-admin-secret` credentials we defined above.

Walk through the Ops Manager setup, accepting defaults. You wil need to add some dummy values for the email server settings. 

Once complete you'll have an Ops Manager almost ready to deal :spades:

### Cleanup Ops Manager admin Secret

**Note** Its safe to remove the `ops-manager-admin-secret` secret from Kubernetes because Ops Manager is configured.

```bash
kubectl delete secret ops-manager-admin-secret -n mongodb
```

## Connect Operator with Ops Manager

* [Configure Ops Manager API Key](#configure-ops-manager-api-key)
* [Configure Ops Manager Connection](#configure-ops-manager-connection)

### Configure Ops Manager API Key

We need to create an API Key for Ops Manager API before the Operator can deploy MongoDB on Kubernetes.  You can do this through the Ops Manager UI.

```txt
# User (Ops Manager upper right corner) > Account > Public API Access > Generate
-------------------------------------------------
Description: om-main-user-credentials
API Key:     ec19ba1c-b63f-4ac4-a55a-d09cca21067d
```

Once the API Key is generated we need to create a Kubernetes Secret containing the User and API Key.

```bash
kubectl create secret generic om-main-user-credentials \
  --from-literal="user=admin@opsmanager.com" \
  --from-literal="publicApiKey=<your-api-key>" \
  -n mongodb
```

### Configure Ops Manager Connection

Next we add a Kubernetes ConfigMap to configure the connection to the Ops Manager endpoint and Project.  The Project will be created if it doesn't exist and this is where MongoDB objects managed by Kubernetes will reside.

```bash
kubectl create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb
```

## Deploy MongoDB with the Operator

* [Deploy Standalone MongoDB](#deploy-standalone-mongodb)
* [Connect to database](#connect-to-database)

### Deploy Standalone MongoDB

At this point Ops Manager is integrated with the Operator and ready to provision MongoDB instances.  Since this demo is on Minikube we'll just deploy a standalone MongoDB instance because you likely don't have enough headroom to deploy anything else on that little ole MacBook. :computer:

You can download the sample template file [here](./mongodb-m0-standalone.yml), or using the cURL command below.

```bash
curl -O https://raw.githubusercontent.com/corbtastik/mongodb-on-k8s/master/mongodb-local/mongodb-m0-standalone.yml
kubectl apply -f mongodb-m0-standalone.yml

# Monitor and wait for database to come up
kubectl -n mongodb get mdb  -w
```

### Connect to database

Get the IP of our Master node and the NodePort exposing our Standalone MongoDB instance.

```bash
# get IP of master Kubernetes node (the only node in Minikube) as you did previously
minikube ip
172.16.182.132
# get NodePort of m0-standalone-svc-external (31793 below)
kubectl -n mongodb get services
NAME                         TYPE        CLUSTER-IP     PORT(S)
m0-standalone-svc            ClusterIP   None           27017/TCP
m0-standalone-svc-external   NodePort    10.96.67.235   27017:31793/TCP
ops-manager-db-svc           ClusterIP   None           27017/TCP
ops-manager-svc              ClusterIP   None           8080/TCP
ops-manager-svc-ext          NodePort    10.96.144.186  8080:31360/TCP
```

Connect from your local machine to the standalone MongoDB instance.

```bash
# connect from mongo shell
mongo 172.16.182.132:31793
MongoDB shell version v4.2.2
connecting to: mongodb://172.16.182.132:31793/test
MongoDB server version: 4.2.3
MongoDB Enterprise > use todosdb
MongoDB Enterprise > db.todos.insertOne({title: "deploy standalone MongoDB on K8s", complete: true})
MongoDB Enterprise > db.todos.insertOne({title: "deploy MongoDB replicaset on K8s", complete: false})
MongoDB Enterprise > db.todos.insertOne({title: "deploy MongoDB sharded cluster on K8s", complete: false})
MongoDB Enterprise > db.todos.find({complete: true}, {_id:0})
MongoDB Enterprise > exit
```

## SA Mindtickle Module

If you are completing this exercise as part of an SA Mindtickle Module, run the following commands in order to generate the output required to submit in Mindtickle itself:
```bash
kubectl get -o=yaml mongodb.mongodb.com,\
opsmanagers.mongodb.com,\
mongodbusers.mongodb.com,\
cm,\
secrets,\
pods 
```

## Teardown

Save a :evergreen_tree:...run the commands below to uninstall all of the Kubernetes components

```bash
kubectl delete ns mongodb
kubectl delete crd mongodb.mongodb.com
kubectl delete crd mongodbusers.mongodb.com
kubectl delete crd opsmanagers.mongodb.com
```

Finally to remove the minikube VM, run the following command:

```bash
minikube delete
```

## Downloads

Install kubectl

```bash
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
```

Install Minikube direct

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64 \
  && sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

## References

1. [Ops Manager in K8s](https://www.mongodb.com/blog/post/running-mongodb-ops-manager-in-kubernetes)
1. [Ops Manager Resource Docs](https://docs.mongodb.com/kubernetes-operator/v1.4/reference/k8s-operator-om-specification/)
1. [MongoDB Enterprise Kubernetes Operator](https://github.com/mongodb/mongodb-enterprise-kubernetes)
