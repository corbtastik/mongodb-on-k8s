**Work in Progress**

# MongoDB on GKE

This document describes how to demo the [MongoDB Enterprise Kubernetes Operator](https://docs.mongodb.com/kubernetes-operator/master/) on GKE.  The goal of this demo is to reinforce the Freedom to Run Anywhere by showing how easy it is to deploy, run and consume MongoDB on Kubernetes.

The MongoDB Enterprise Operator for Kubernetes allows devOps teams to:

* Deploy and run MongoDB Ops Manager on K8s  
* Deploy and manage MongoDB clusters on K8s

## TOC

* Install Common Prerequisites
* Install GKE Infrastructure
* Install MongoDB Enterprise Kubernetes Operator
* Deploy MongoDB Ops Manager on Kubernetes
* Configure MongoDB Operator with Ops Manager API Key
* Deploy and Use MongoDB Standalone on Kubernetes
* Deploy and Use MongoDB ReplicaSet on Kubernetes
* (Optional) Deploy and Use MongoDB Shared Cluster on Kubernetes

## Install Common Prerequisites

There's several ways to install and setup each of these so pick a method that works for you.  Options are documented in the links below.

* [Google Cloud SDK](https://cloud.google.com/sdk) - for interacting with GCP and GKE
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - for interacting with Kubernetes
* [MongoDB Enterprise](https://www.mongodb.com/download-center/enterprise) - Installed locally for mongo client

You should be able to resolve each from the command line.

```bash
$ gcloud version
Google Cloud SDK 279.0.0
bq 2.0.53
core 2020.01.31
gsutil 4.47

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

## Install GKE Infrastructure

__TODO__ describe deploying a test cluster

## Install MongoDB Enterprise Kubernetes Operator

**Note** - this is a demo and not intended for production use.

Create a namespace for all MongoDB assets.

```bash
kubectl create namespace mongodb
```

Create Custom Resource Definitions

* MongoDB
* MongoDBUser
* MongoDBOpsManager

```bash
# Download Custom Resource Definitions
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
kubectl apply -f crds.yaml
# Download MongoDB Enterprise Operator
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
kubectl apply -f mongodb-enterprise.yaml
```

Create a K8s Secret to hold the Ops Manager Admin creds.

```bash
kubectl create secret generic ops-manager-admin-secret \
--from-literal=Username="admin@opsmanager.com" \
--from-literal=Password="Passw0rd." \
--from-literal=FirstName="Ops" \
--from-literal=LastName="Manager" \
-n mongodb
```

## Deploy MongoDB Ops Manager on Kubernetes

Deploy MongoDB Ops Manager with a 3 member MongoDB ReplicaSet for the application database.  Startup time will vary based on hardware, however expect to wait 5-10 mins for everything to reach Running status.

```bash
kubectl apply -f mongodb-ops-manager.yml
# wait a few mins for the objects to create
kubectl -n mongodb get om -w
# should have these objects
kubectl -n mongodb get pods -o wide  
NAME                        READY  STATUS             RESTARTS  AGE
mongodb-enterprise-operator 1/1    Running            0         176m
ops-manager-0               1/1    Running            0         172m
ops-manager-db-0            1/1    Running            0         176m
ops-manager-db-1            1/1    Running            0         175m
ops-manager-db-2            1/1    Running            0         173m
```

The deployment creates a LoadBalancer on GKE with an `EXTERNAL-IP` that we can use to access Ops Manager.

```bash
$ kubectl -n mongodb get service ops-manager-svc-ext

NAME                  TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
ops-manager-svc-ext   LoadBalancer   10.0.6.39    34.70.50.63   8080:31231/TCP   61m
```

Open a Browser to ``http://EXTERNAL-IP:8080`` and login with the `ops-manager-admin-secret` creds above.

![Ops Manager Login](/assets/GKE-OpsManagerLogin.png)

Now remove the `ops-manager-admin-secret` secret from Kubernetes because you remember it right?

```bash
$ kubectl -n mongodb delete secret ops-manager-admin-secret
```

Walk through the Ops Manager setup, accepting the defaults.  Once complete you'll have an Ops Manager almost ready to deal.

## Configure MongoDB Operator with Ops Manager API Key

We need to create an API Key before the MongoDB Operator can deploy MongoDB on Kubernetes.  You can do this through the Ops Manager UI.

![Ops Manager Login](/assets/GKE-OpsManagerOverview.png)

```txt
# User (upper right) > Account > Public API Access > Generate
-------------------------------------------------
Description: om-main-user-credentials
API Key:     8f1cc51e-15c7-4f55-9ece-a9bdfd9e012b
```

![GKE-OpsManagerAPIKey](/assets/GKE-OpsManagerAPIKey.png)

Once the API Key is created we need to create a Kubernetes [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) containing the API Key plus a [ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) to configure the connection to Ops Manager.  The Project specified will be created in Ops Manager if it doesn't exist.

```bash
kubectl create secret generic om-main-user-credentials \
  --from-literal="user=admin@opsmanager.com" \
  --from-literal="publicApiKey=8f1cc51e-15c7-4f55-9ece-a9bdfd9e012b" \
  -n mongodb
```

```bash
kubectl create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb
```

Now we're all set to deploy our first MongoDB resource on Kubernetes!

## Deploy and Use MongoDB Standalone on Kubernetes

First deploy a standalone MongoDB instance using the sample `mongodb-m0-standalone.yml` resource.  For more details on the MongoDB resource checkout the docs [here](https://docs.mongodb.com/kubernetes-operator/v1.4/tutorial/deploy-standalone/).  The spec.credentials and spec.opsManager.configMapRef.name need to match the configurations above.

A NodePort service will be created as well since exposedExternally is set to true.

```yaml
apiVersion: mongodb.com/v1
kind: MongoDB
metadata:
  name: m0-standalone
  namespace: mongodb
spec:
  version: 4.2.3-ent
  type: Standalone
  persistent: true
  exposedExternally: true
  credentials: om-main-user-credentials
  opsManager:
    configMapRef:
      name: ops-manager-connection
```

Apply the resource and wait for it to come up.

```bash
kubectl apply -f mongodb-m0-standalone.yml
kubectl -n mongodb get mdb  -w
```

Once running you should be able to see it as a "Workload" in the GKE UI.

![GKE-m0-standalone](/assets/GKE-m0-standalone.png)

Next we need to create a LoadBalancer so we can connect to the standalone instance.  Use the `mongodb-m0-loadbalancer.yml` to create a LoadBalancer that will round-robin traffic across our 3 Worker Nodes using the ClusterIP (27017).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: m0-standalone-svc-ext
  namespace: mongodb
  labels:
    app: m0-standalone-svc
spec:
  externalTrafficPolicy: Cluster
  ports:
  - port: 27017
    protocol: TCP
    targetPort: 27017
  selector:
    app: m0-standalone-svc
  sessionAffinity: None
  type: LoadBalancer
```

```bash
$ kubectl apply -f mongodb-m0-loadbalancer.yml
```

Get the `EXTERNAL-IP` of the LoadBalancer `m0-standalone-svc-ext`.

```bash
$ kubectl -n mongodb get services
NAME                         TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)           AGE
m0-standalone-svc            ClusterIP      None          <none>        27017/TCP         49m
m0-standalone-svc-ext        LoadBalancer   10.0.11.168   35.193.42.3   27017:32065/TCP   12m
m0-standalone-svc-external   NodePort       10.0.1.187    <none>        27017:31190/TCP   8m37s
ops-manager-db-svc           ClusterIP      None          <none>        27017/TCP         4h11m
ops-manager-svc              ClusterIP      None          <none>        8080/TCP          4h8m
ops-manager-svc-ext          LoadBalancer   10.0.6.39     34.70.50.63   8080:31231/TCP    4h8m
```

Connect to the standalone instance using the mongo client on your local box.  Use the EXTERNAL-IP of the LoadBalancer above.

```bash
mongo 35.193.42.3
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

Flip over to Ops Manager and you should see the Standalone instance and the new `todosdb`.

![GKE-m0-standalone-data](/assets/GKE-m0-standalone-data.png)


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

### Teardown

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

### Nice commands to know

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

### References

1. [Ops Manager in K8s](https://www.mongodb.com/blog/post/running-mongodb-ops-manager-in-kubernetes)
1. [Ops Manager Resource Docs](https://docs.mongodb.com/kubernetes-operator/v1.4/reference/k8s-operator-om-specification/)
1. [MongoDB Enterprise Kubernetes Operator](https://github.com/mongodb/mongodb-enterprise-kubernetes)
