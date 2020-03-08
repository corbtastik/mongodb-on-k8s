# MongoDB on K8s - Minikube

This document describes how to demo the [MongoDB Enterprise Kubernetes Operator](https://docs.mongodb.com/kubernetes-operator/master/) to stamp out MongoDB instances on your MacBook using [Minikube](https://minikube.sigs.k8s.io/).

_The demo environment runs on Minikube and can be taxing to a MacBook, as such it's recommended to shutdown non-essentials for the best experience (close those Chrome tabs?)._ 🤔

_It also might be good to consider using [VMware Fusion](https://www.vmware.com/products/fusion/fusion-evaluation.html) over VirtualBox which will improve your experience running VMs locally._

## TOC

* [Install Required Infra](./install-required-infra)
* [Deploy Operator](./deploy-operator)
* [Deploy MongoDB Ops Manager](./deploy-mongodb-ops-manager)
* [Connect Operator with Ops Manager](./connect-operator-with-ops-manager)
* [Deploy MongoDB with the Operator](./deploy-mongodb-with-the-operator)

---

## Install Required Infra

Install the following tools on your MacBook.  There's several ways to install and setup each of these so pick a method that works for you.  Install options are documented in the links below.

* [VirtualBox (v6.0)](https://www.virtualbox.org/wiki/Download_Old_Builds_6_0) - Required for virtualization substrate
* [Minikube (v1.6.x)](https://minikube.sigs.k8s.io/docs/start/) - VM running Kubernetes
* [Kubectl (v1.17.x)](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for interacting with Kubernetes
* [MongoDB Enterprise (v4.2.x)](https://www.mongodb.com/download-center/enterprise) - Installed locally for mongo client

You should be able to resolve each from the command line.

```bash
# virtualbox version
$ vboxmanage --version
6.0.16r135674

$ minikube version
minikube version: v1.6.2

$ kubectl version -o json
{
  "clientVersion": {
    "major": "1",
    "minor": "17",
    "gitVersion": "v1.17.2",
    "gitCommit": "59603c6e503c87169aea6106f57b9f242f64df89",
    "gitTreeState": "clean",
    "buildDate": "2020-01-18T23:30:10Z",
    "goVersion": "go1.13.5",
    "compiler": "gc",
    "platform": "darwin/amd64"
  }
}

$ mongo --version
MongoDB shell version v4.2.3
```

---

## Deploy Operator

* [Configure and Start Minikube](./configure-and-start-minikube)
* [Create mongodb namespace](./create-mongodb-namespace)
* [Apply MongoDB Custom Resource Definitions](./apply-mongodb-custom-resource-definitions)
* [Deploy MongoDB Operator](./deploy-mongodb-operator)

### Configure and Start Minikube

Configure cpu, memory and vm-driver for your tastes and run `start.sh` to boot Minikube.

```bash
# start.sh
# use --vm-driver=vmware if you have VMware Fusion installed
minikube start --vm-driver=virtualbox \
  --cpus=4 \       # as much as you can give
  --memory=10240 \ # ditto
  --disk-size=64g \
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

---

## Deploy MongoDB Ops Manager

**Note:** Deploying Ops Manager with the Operator is currently in beta (03/01/2020) but we're doing so because having everything run in K8s is a bit convenient and cool. :sunglasses:

* [Configure Ops Manager Deployment](./configure-ops-manager-deployment)
* [Deploy Ops Manager](./deploy-ops-manager)
* [Setup Ops Manager](./setup-ops-manager)
* [Cleanup Ops Manager admin Secret](./cleanup-ops-manager-admin-secret)

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

Ensure `mongodb-ops-manager.yml` has `NodePort` configured for external connectivity and you disable backup for Ops Manager. Not a best practice but we're running on Minikube and resources are precious. :gem:

```yaml
  externalConnectivity:
    type: NodePort
  backup:
    enabled: false    
```

### Deploy Ops Manager

Deploy MongoDB Ops Manager in a Pod as well as a 3 member MongoDB ReplicaSet for the Ops Manager application database.  Startup time will vary based on Hardware and quota given to Minikube, however expect to wait 5-10 mins for everything to reach Running status.


```bash
kubectl apply -f mongodb-ops-manager.yml
# wait a few mins for the objects to create
kubectl -n mongodb get om -w
# should have these objects
kubectl -n mongodb get pods -o wide  
NAME                        READY  STATUS             RESTARTS  AGE
mongodb-enterprise-operator 1/1    Running            0         62m
ops-manager-0               1/1    Running            0         7m3s
ops-manager-db-0            1/1    Running            0         9m20s
ops-manager-db-1            1/1    Running            0         8m24s
ops-manager-db-2            1/1    Running            0         7m48s
```

### Setup Ops Manager

Open MongoDB Ops Manager at ``http://INTERNAL-IP:NODE-PORT`` and login with the `ops-manager-admin-secret` creds above.  To get the right endpoint for Ops Manager retrieve the node's INTERNAL-IP and NodePort.

```bash
# get INTERNAL-IP
kubectl -n mongodb get node -o wide
# get high-side NODE-PORT, should be something like 3xxxx
kubectl -n mongodb get service ops-manager-svc-ext
```

Walk through the Ops Manager setup, accepting defaults.  Once complete you'll have an Ops Manager almost ready to deal :spades:

### Cleanup Ops Manager admin Secret

**Note** Its safe to remove the `ops-manager-admin-secret` secret from Kubernetes because Ops Manager is configured.

```bash
kubectl delete secret ops-manager-admin-secret -n mongodb
```

---

## Connect Operator with Ops Manager

* [Configure Ops Manager API Key](./configure-ops-manager-api-key)
* [Configure Ops Manager Connection](./configure-ops-manager-connection)

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
  --from-literal="publicApiKey=ec19ba1c-b63f-4ac4-a55a-d09cca21067d" \
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

---

## Deploy MongoDB with the Operator

* [Deploy Standalone MongoDB](./deploy-standalone-mongodb)
* [Connect to database](./connect-to-database)

### Deploy Standalone MongoDB

At this point Ops Manager is integrated with the Operator and ready to provision MongoDB instances.  Since this demo is on Minikube we'll just deploy a standalone MongoDB instance because you likely don't have enough headroom to deploy anything else on that little ole MacBook. :computer:

```bash
kubectl apply -f mongodb-m0-standalone.yml
# wait for database to come up
kubectl -n mongodb get mdb  -w
```

### Connect to database

Get the IP of our Master node and the NodePort exposing our Standalone MongoDB instance.

```bash
# get IP of master Kubernetes node (the only node in Minikube)
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

## Teardown

Save a :evergreen_tree:...run the commands below to uninstall all Service Instances, remove the Atlas OSB and Service Catalog.

```bash
kubectl delete ns mongodb
kubectl delete crd mongodb.mongodb.com
kubectl delete crd mongodbusers.mongodb.com
kubectl delete crd opsmanagers.mongodb.com
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
