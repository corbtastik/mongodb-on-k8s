# MongoDB on K8s - Minikube

This document describes how to demo the [MongoDB Enterprise Kubernetes Operator](https://docs.mongodb.com/kubernetes-operator/master/) on your MacBook using [Minikube](https://minikube.sigs.k8s.io/).  The goal of this demo is to reinforce the Freedom to Run Anywhere by showing how easy it is to deploy, run and consume MongoDB on Kubernetes.

The MongoDB Enterprise Operator for Kubernetes allows devOps teams to:

* Deploy and run MongoDB Ops Manager on K8s  
* Deploy and manage MongoDB clusters on K8s

_The demo environment runs on Minikube and can be taxing to a MacBook, as such it's recommended to shutdown non-essentials for the best experience (close those Chrome tabs?)._ 🤔

_It also might be good to consider using [VMware Fusion](https://www.vmware.com/products/fusion/fusion-evaluation.html) over VirtualBox which will improve your experience running VMs locally._

## TOC

* Install Required Infrastructure
* Install MongoDB Enterprise Kubernetes Operator
* Deploy MongoDB Ops Manager on Kubernetes
* Configure MongoDB Operator with Ops Manager API Key
* Deploy and Use MongoDB Standalone on Kubernetes
* Deploy and Use MongoDB ReplicaSet on Kubernetes
* (Optional) Deploy and Use MongoDB Shared Cluster on Kubernetes

## Install Required Infrastructure

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

## Initial setup

Configure cpu, memory and vm-driver for your tastes and start Minikube.

```bash
# start.sh
# use --vm-driver=vmware if you have VMware Fusion installed
minikube start --vm-driver=virtualbox \
  --cpus=4 \
  --memory=10240 \ # as much as you can afford
  --disk-size=64g \
  --mount-string="$HOME/data:/data" \
  --kubernetes-version=1.15.10  
```

Create a namespace for all MongoDB assets.

```bash
kubectl create namespace mongodb
```

Create [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

* [MongoDB](https://docs.mongodb.com/kubernetes-operator/stable/reference/k8s-operator-specification/) - K8s resource for MongoDB objects such as Standalone, ReplicaSet and ShardedClusters
* MongoDBUser - K8s resource for MongoDB users
* [MongoDBOpsManager](https://docs.mongodb.com/kubernetes-operator/stable/reference/k8s-operator-om-specification/) - K8s resource for MongoDB Enterprise Ops Manager

```bash
# Download Custom Resource Definitions
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
kubectl apply -f crds.yaml
# Download MongoDB Enterprise Operator
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
kubectl apply -f mongodb-enterprise.yaml
```

## Deploy MongoDB Kubernetes Operator

Create Ops Manager credentials as a K8s Secret.

```bash
kubectl create secret generic ops-manager-admin-secret \
--from-literal=Username="admin@opsmanager.com" \
--from-literal=Password="Passw0rd." \
--from-literal=FirstName="Ops" \
--from-literal=LastName="Manager" \
-n mongodb
```

Ensure `mongodb-ops-manager.yml` has `NodePort` configured for external connectivity and you disable backup for Ops Manager. Not a best practice but we're running on Minikube and resources locally are precious :gem:.

```yaml
  externalConnectivity:
    type: NodePort
  backup:
    enabled: false    
```

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

Open MongoDB Ops Manager and login with the `ops-manager-admin-secret` creds above.  To get the right endpoint for Ops Manager retrieve the node's INTERNAL-IP and NodePort.

```bash
# remember INTERNAL-IP
kubectl -n mongodb get node -o wide
# remember high-side NODE-PORT, should be something like 3xxxx
kubectl -n mongodb get service ops-manager-svc-ext
```

Open a Browser to ``http://INTERNAL-IP:NODE-PORT``

![Ops Manager Login](/assets/OpsManagerLogin.png)

Remove the `ops-manager-admin-secret` secret from Kubernetes because you remember it right?

```bash
kubectl delete secret ops-manager-admin-secret -n mongodb
```

Walk through the Ops Manager setup, accepting the defaults.  Once complete you'll have an Ops Manager almost ready to deal.

![Ops Manager Login](/assets/OpsManagerOverview.png)

## Configure MongoDB Operator with Ops Manager API Key

We need to create an API Key for Ops Manager API before the MongoDB Operator can deploy MongoDB on Kubernetes.  You can do this through the Ops Manager UI.  Once the API Key is generated we need to create a Kubernetes Secret containing the User and API Key.

```txt
# User (Ops Manager upper right corner) > Account > Public API Access > Generate
-------------------------------------------------
Description: om-main-user-credentials
API Key:     ec19ba1c-b63f-4ac4-a55a-d09cca21067d
```

```bash
kubectl create secret generic om-main-user-credentials \
  --from-literal="user=admin@opsmanager.com" \
  --from-literal="publicApiKey=ec19ba1c-b63f-4ac4-a55a-d09cca21067d" \
  -n mongodb
```

Next we need to add a Kubernetes ConfigMap to configure the connection to the Ops Manager endpoint and Project.  The Project will be created if it doesn't exist and this is where MongoDB objects managed by Kubernetes will reside.

```bash
kubectl create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb
```

## Deploy and Use MongoDB Standalone on Kubernetes

__step-10__

```bash
kubectl apply -f mongodb-m0-standalone.yml
# wait for database to come up
kubectl -n mongodb get mdb  -w
```

__step-11__

Connect from your local machine to the standalone MongoDB instance

```bash
# get IP of master Kubernetes node (the only node in Minikube)
minikube ip
# get NodePort of m0-standalone-svc-external (31793 below)
kubectl -n mongodb get services
NAME                         TYPE        CLUSTER-IP     PORT(S)
m0-standalone-svc            ClusterIP   None           27017/TCP
m0-standalone-svc-external   NodePort    10.96.67.235   27017:31793/TCP
ops-manager-db-svc           ClusterIP   None           27017/TCP
ops-manager-svc              ClusterIP   None           8080/TCP
ops-manager-svc-ext          NodePort    10.96.144.186  8080:31360/TCP
```

__step-12__

```bash
# connect from local machine
mongo 172.16.182.132:31793
MongoDB shell version v4.2.2
connecting to: mongodb://172.16.182.132:31793/test
MongoDB server version: 4.2.3
MongoDB Enterprise > use todosdb
MongoDB Enterprise > db.todos.insertOne({title: "deploy standalone MongoDB on K8s", complete: true})
MongoDB Enterprise > db.todos.insertOne({title: "deploy MongoDB replicaset on K8s", complete: false})
MongoDB Enterprise > db.todos.insertOne({title: "deploy MongoDB sharded cluster on K8s", complete: false})
MongoDB Enterprise > db.todos.find({complete: false})
MongoDB Enterprise > exit
```

## Deploy and Use MongoDB ReplicaSet on Kubernetes

__step-13__

```bash
kubectl apply -f mongodb-m1-replicaset.yml
kubectl -n mongodb get mdb/m1-replica-set -w
# wait until the ReplicaSet is Running
NAME             TYPE         STATE         VERSION     AGE
m1-replica-set   ReplicaSet   Reconciling   4.2.3-ent   58s
m1-replica-set   ReplicaSet   Running       4.2.3-ent   66s
# verify 3 pods are running for the ReplicaSet
NAME                                           READY   STATUS    
m1-replica-set-0                               1/1     Running
m1-replica-set-1                               1/1     Running
m1-replica-set-2                               1/1     Running
```

__step-14__

This time we're going to issue mongo client commands from within the Pod network.  You can grab the connection string from Ops Manager by clicking the "..." button on the ReplicaSet and then select "Connect to this Instance"...copy the connection string (see screenshot).

![ReplicaSet Connection String](/assets/ReplicaSetConnectionString.png)

Now exec into a shell on the Primary Pod and add some data.

```bash
# You can find the primary from Ops Manager UI, in most cases it will be -0
kubectl -n mongodb exec -it m1-replica-set-0 sh
# Now in the Pod shell...copy the connection string to connect
$ /var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.2.3-ent/bin/mongo \
  --host m1-replica-set-0.m1-replica-set-svc.mongodb.svc.cluster.local \
  --port 27017
MongoDB shell version v4.2.3
connecting to: mongodb://m1-replica-set-0...blah blah blah
MongoDB Enterprise m1-replica-set:PRIMARY> use todosdb
MongoDB Enterprise m1-replica-set:PRIMARY> db.todos.insertOne({title: "deploy standalone MongoDB on K8s", complete: true})
MongoDB Enterprise m1-replica-set:PRIMARY> db.todos.insertOne({title: "deploy MongoDB replicaset on K8s", complete: true})
MongoDB Enterprise m1-replica-set:PRIMARY> db.todos.insertOne({title: "deploy MongoDB sharded cluster on K8s", complete: false})
MongoDB Enterprise m1-replica-set:PRIMARY> db.todos.find({complete: false}).pretty()
{
	"_id" : ObjectId("5e38ebcf1ac70e1e4ff81efe"),
	"title" : "deploy MongoDB sharded cluster on K8s",
	"complete" : false
}
```

__step-15__  

Now remove the ReplicaSet.

```bash
kubectl -n mongodb delete mdb/m1-replica-set
```

## Teardown

__TODO__ clean this up

```bash
kubectl delete pvc mongodb-standalone
kubectl delete pv mongodb-standalone
kubectl delete namespace mongodb
kubectl delete storageclass mongodb-standalone
kubectl delete crd mongodb.mongodb.com
kubectl delete crd mongodbusers.mongodb.com
kubectl delete crd opsmanagers.mongodb.com

kubectl delete secret mongodb-admin-creds
kubectl delete secret ops-manager-admin-secret
kubectl delete secret ops-manager-admin-secret
```

## Nice commands to know

__TODO__ clean this up

Set context to mongodb namespace

```bash
kube config set-context --current --namespace=mongodb
```

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
