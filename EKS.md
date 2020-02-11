**Work in Progress**

# MongoDB on EKS

**Note** - This is a demo kit and not intended for production use in any way, its intended for simple demos and general knowledge...and perhaps for having some cooleo nerd fun :sunglasses:.

This document describes how to demo the [MongoDB Enterprise Kubernetes Operator](https://docs.mongodb.com/kubernetes-operator) on [EKS](https://aws.amazon.com/eks/).  The goal of this demo is to reinforce the Freedom to Run Anywhere by showing how easy it is to deploy, run and consume MongoDB on Kubernetes on [AWS](https://aws.amazon.com/) EKS.

The [MongoDB Enterprise Operator for Kubernetes](https://docs.mongodb.com/kubernetes-operator) allows devOps teams to:

* Deploy and run MongoDB Ops Manager on K8s infra
* Deploy and manage MongoDB Standalone, ReplicaSets and Shared Clusters on K8s infra
* Benefit from K8s devOps goodness - extensibility, elasticity, resiliency...etc.

## TOC

* Install Prerequisites
* Provision AWS Infrastructure
* Install MongoDB Enterprise Kubernetes Operator
* Deploy MongoDB Ops Manager on Kubernetes
* Configure MongoDB Operator with Ops Manager API Key
* Deploy and Use MongoDB Standalone on Kubernetes
* Deploy and Use MongoDB ReplicaSet on Kubernetes
* (Optional) Deploy and Use MongoDB Shared Cluster on Kubernetes

## Install Prerequisites

There are several ways to get started with EKS so feel free to choose a method that works for you.  In this demo kit we use [eksctl](https://eksctl.io/) to provision Kubernetes assets on AWS.

**Note** - There are 2 versions of the AWS CLI at this time v1 and v2. **[This guide uses v1](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html)**.

* [AWS CLI v1](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html) - for interacting with AWS
* [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html) - for interacting with EKS (includes docs for installing AWS CLI and aws-iam-authenticator as well).
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - for interacting with Kubernetes
* [MongoDB Enterprise](https://www.mongodb.com/download-center/enterprise) - Installed locally for mongo client

You should be able to resolve each from the command line before continuing.

```bash
# AWS CLI v1
$ aws --version
aws-cli/1.17.13 Python/3.7.5 Darwin/18.7.0 botocore/1.14.13

# AWS IAM authenticator, used by eksctl and kubectl
$ aws-iam-authenticator version
{"Version":"v0.4.0","Commit":"c141eda34ad1b6b4d71056810951801348f8c367"}

# eksctl, used to interact with EKS
$ eksctl version  
[ℹ]  version.Info{BuiltAt:"", GitCommit:"", GitTag:"0.13.0"}

# kubectl client used to interact with Kubernetes
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

# mongo client used to mongo on.
$ mongo --version
MongoDB shell version v4.2.3
```

## Provision AWS Infrastructure

First we need a Kubernetes Cluster and here's a [handy video](https://eksworkshop.com/030_eksctl/) on using eksctl to provision one...lucky you :four_leaf_clover:.

This command will provision everything you need, the K8s control plane as well as 3 worker nodes.  By default it uses [m5.large EC2 instances](https://aws.amazon.com/ec2/instance-types/m5/), official AWS EKS AMI, a dedicated VPC and public access to K8s infra.  Expect to wait around 10-15 minutes for everything to provision.

```bash
# customize the name and region to your taste
$ eksctl create cluster --name mongodb-on-k8s --nodes 3 --region us-west-2
```

You can view progress from the command line as well as the EKS, Cloud Formation and/or the EC2 AWS Console.
![EKS-EC2-console](/assets/EKS-EC2-console.png)
After 15 minutes or so you should see ready message from the eksctl console.

```bash
[ℹ]  node "ip-192-168-55-47.us-west-2.compute.internal" is ready
[ℹ]  node "ip-192-168-87-68.us-west-2.compute.internal" is ready
[ℹ]  node "ip-192-168-9-208.us-west-2.compute.internal" is ready
[ℹ]  kubectl command should work with "/Users/corbs/.kube/config", try 'kubectl get nodes'
[✔]  EKS cluster "mongodb-on-k8s" in "us-west-2" region is ready

$ kubectl get nodes
NAME                                          STATUS   ROLES    AGE   VERSION
ip-192-168-55-47.us-west-2.compute.internal   Ready    <none>   34m   v1.14.8-eks-b8860f
ip-192-168-87-68.us-west-2.compute.internal   Ready    <none>   34m   v1.14.8-eks-b8860f
ip-192-168-9-208.us-west-2.compute.internal   Ready    <none>   34m   v1.14.8-eks-b8860f
```

This concludes AWS infra, in certain demo scenarios you could pre-prep all of this and start with the MongoDB section below.  Now on to the good stuff.

## Install MongoDB Enterprise Kubernetes Operator

Create a namespace for all MongoDB assets.

```bash
$ kubectl create namespace mongodb
```

Create Custom Resource Definitions for objects we're going to provision with the Operator.

* MongoDB - K8s resource for MongoDB objects such as Standalone, ReplicaSet and SharedClusters
* MongoDBUser - K8s resource for MongoDB users
* MongoDBOpsManager - K8s resource for MongoDB Enterprise Ops Manager

```bash
# Download Custom Resource Definitions
$ curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
$ kubectl apply -f crds.yaml
# Download MongoDB Enterprise Operator
$ curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
$ kubectl apply -f mongodb-enterprise.yaml
```

Create a K8s [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) to hold the Ops Manager Admin creds. Change the properties to whatever you want...remember this is a demo :smiley:

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

The deployment creates a [LoadBalancer on EKS](https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html) with a generated DNS record we can use to access Ops Manager.

```bash
$ kubectl -n mongodb get service ops-manager-svc-ext

NAME                  TYPE           CLUSTER-IP     EXTERNAL-IP                                                              PORT(S)          AGE
ops-manager-svc-ext   LoadBalancer   10.100.36.210  ac792e0f34cef11ea8398027a0aa1064-813290281.us-west-2.elb.amazonaws.com   8080:30979/TCP   89m
```

Open a Browser to ``http://EXTERNAL-IP:8080`` and login with the `ops-manager-admin-secret` creds above.

![Ops Manager Login](/assets/EKS-OpsManagerLogin.png)

Now remove the `ops-manager-admin-secret` secret from Kubernetes because you remember it right?

```bash
$ kubectl -n mongodb delete secret ops-manager-admin-secret
```

Walk through the Ops Manager setup, accepting defaults.  Once complete you'll have an Ops Manager almost ready to deal.

## Configure MongoDB Operator with Ops Manager API Key

We need to create an API Key before the MongoDB Operator can deploy MongoDB on Kubernetes.  You can do this through the Ops Manager UI.

```txt
# Ops Manager UI
# User (upper right) > Account > Public API Access > Generate > Pop-Up > Generate
---------------------------------------------------------------------------------
Description: om-main-user-credentials
API Key:     72112e4a-a7aa-40d4-a24f-8c8311345bd6 #remember
```
<!-- ![Ops Manager Login](/assets/EKS-OpsManagerOverview.png) -->
![GKE-OpsManagerAPIKey](/assets/EKS-OpsManagerAPIKey.png)

Once the API Key is created we need to create a Kubernetes [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) containing the API Key plus a [ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) to configure the connection endpoint to Ops Manager.  The Project specified will be created in Ops Manager if it doesn't exist, this Project will contain MongoDB databases managed my Kubernetes.

```bash
$ kubectl create secret generic om-main-user-credentials \
  --from-literal="user=admin@opsmanager.com" \
  --from-literal="publicApiKey=72112e4a-a7aa-40d4-a24f-8c8311345bd6" \
  -n mongodb
```

```bash
$ kubectl create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb
```

Now we're all set to deploy our first MongoDB database on Kubernetes! #mongo-on

## Deploy and Use MongoDB Standalone on Kubernetes

A simple first demo is deploying a standalone MongoDB instance using the sample `mongodb-m0-standalone.yml` resource.  For more details on the MongoDB resource checkout the docs [here](https://docs.mongodb.com/kubernetes-operator/v1.4/tutorial/deploy-standalone/).  The `spec.credentials` and `spec.opsManager.configMapRef.name` need to match the Secret and ConfigMap configurations above.

```yaml
# mongodb-m0-standalone.yml
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
$ kubectl apply -f mongodb-m0-standalone.yml
$ kubectl -n mongodb get mdb  -w
```

Once complete you should be able to see the pods and services running.

```bash
$ kubectl -n mongodb get pods
NAME                                           READY   STATUS    RESTARTS   AGE
m0-standalone-0                                1/1     Running   0          6m48s
mongodb-enterprise-operator-54ccddcd7f-rzbsd   1/1     Running   0          75m
ops-manager-0                                  1/1     Running   0          39m
ops-manager-db-0                               1/1     Running   0          42m
ops-manager-db-1                               1/1     Running   0          41m
ops-manager-db-2                               1/1     Running   0          40m

$ kubectl -n mongodb get svc
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)           AGE
m0-standalone-svc            ClusterIP      None            <none>                                                                   27017/TCP         8m25s
m0-standalone-svc-external   NodePort       10.100.14.164   <none>                                                                   27017:30713/TCP   8m25s
ops-manager-db-svc           ClusterIP      None            <none>                                                                   27017/TCP         44m
ops-manager-svc              ClusterIP      None            <none>                                                                   8080/TCP          41m
ops-manager-svc-ext          LoadBalancer   10.100.36.210   ac792e0f34cef11ea8398027a0aa1064-813290281.us-west-2.elb.amazonaws.com   8080:30979/TCP    41m
```

Next we can create a LoadBalancer so we can connect to the standalone instance.  Use the `mongodb-m0-loadbalancer.yml` to create an ELB that will round-robin traffic across our 3 K8s Worker Nodes using the ClusterIP (27017).

```yaml
# mongodb-m0-loadbalancer.yml
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
$ kubectl -n mongodb get services
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)           AGE
m0-standalone-svc            ClusterIP      None            <none>                                                                    27017/TCP         17m
m0-standalone-svc-ext        LoadBalancer   10.100.216.31   ac5c5f8b64cf611ea8398027a0aa1064-1351410667.us-west-2.elb.amazonaws.com   27017:31373/TCP   10s
m0-standalone-svc-external   NodePort       10.100.14.164   <none>                                                                    27017:30713/TCP   17m
ops-manager-db-svc           ClusterIP      None            <none>                                                                    27017/TCP         53m
ops-manager-svc              ClusterIP      None            <none>                                                                    8080/TCP          50m
ops-manager-svc-ext          LoadBalancer   10.100.36.210   ac792e0f34cef11ea8398027a0aa1064-813290281.us-west-2.elb.amazonaws.com    8080:30979/TCP    50m
```

Connect to the standalone instance using the mongo client on your local box.  Use the `EXTERNAL-IP` of the `m0-standalone-svc-ext` LoadBalancer above.

```bash
$ mongo ac5c5f8b64cf611ea8398027a0aa1064-1351410667.us-west-2.elb.amazonaws.com
MongoDB shell version v4.2.3
connecting to: mongodb://ac5c5f8b64cf611ea8398027a0aa1064-1351410667.us-west-2.elb.amazonaws.com:27017/test?compressors=disabled&gssapiServiceName=mongodb
MongoDB server version: 4.2.3
MongoDB Enterprise > use todosdb
MongoDB Enterprise > db.todos.insertOne({title: "deploy standalone MongoDB on K8s", complete: true})
MongoDB Enterprise > db.todos.insertOne({title: "deploy MongoDB replicaset on K8s", complete: false})
MongoDB Enterprise > db.todos.insertOne({title: "deploy MongoDB sharded cluster on K8s", complete: false})
MongoDB Enterprise > db.todos.find({complete: false})
MongoDB Enterprise > exit
```

Flip over to Ops Manager and you should see the Standalone instance and the new `todosdb`.
![GKE-m0-standalone-data](/assets/EKS-m0-standalone.png)

Bada Bing Bada :boom:...now delete the Standalone instance and LoadBalancer service.

```bash
$ kubectl -n mongodb delete mdb/m0-standalone
$ kubectl -n mongodb delete service m0-standalone-svc-ext
```


## Deploy and Use MongoDB ReplicaSet on Kubernetes

Now lets deploy a 3 member MongoDB ReplicaSet on K8s and connect with the mongo client.

```bash
$ kubectl apply -f mongodb-m1-replicaset.yml
$ kubectl -n mongodb get mdb/m1-replica-set -w

# wait until the ReplicaSet is Running
NAME             TYPE         STATE         VERSION     AGE
m1-replica-set   ReplicaSet   Reconciling   4.2.3-ent   10m
m1-replica-set   ReplicaSet   Running       4.2.3-ent   10m

# verify statefulset
$ kubectl -n mongodb get statefulset m1-replica-set
m1-replica-set   3/3     10m

# verify 3 pods are running for the ReplicaSet
$ kubectl -n mongodb get pods
NAME                                           READY   STATUS    
m1-replica-set-0                               1/1     Running
m1-replica-set-1                               1/1     Running
m1-replica-set-2                               1/1     Running
```

This time we're going to issue mongo client commands from within the Pod network.  You can grab the connection string from Ops Manager by clicking the "..." button on the ReplicaSet and then select "Connect to this Instance"...copy the connection string (see screenshot).

![ReplicaSet Connection String](/assets/EKS-ReplicaSetConnectionString.png)

Now exec into a shell on the Primary Pod and add some data.  The Primary Pod is the `host` argument specified in the connection string above.  Substitute your Primary Pod in the commands below.

```bash
# You can find the primary from Ops Manager UI, it's not always m1-replica-set-0
$ kubectl -n mongodb exec -it m1-replica-set-2 sh
# set mongo in PATH on Pod
$ export PATH=/var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.2.3-ent/bin:$PATH
$ mongo
MongoDB shell version v4.2.3
connecting to: mongodb://m1-replica-set-2...blah blah blah
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

View ReplicaSet in Ops Manager
![EKS-m1-standalone-data](/assets/EKS-m1-standalone.png)
:trophy: Alrighty...now remove the ReplicaSet.

```bash
$ kubectl -n mongodb delete mdb/m1-replica-set
```

## Deploy and Use MongoDB Shared Cluster on Kubernetes  

The last sample is deploying and using a simple [Sharded Cluster on K8s](https://docs.mongodb.com/kubernetes-operator/master/tutorial/deploy-sharded-cluster/).  The Cluster in this demo has 2 Shards, each with a 3 node ReplicaSet, 1 Mongos and 1 Config Server.

```yml
# mongodb-m2-shardedcluster.yml
apiVersion: mongodb.com/v1
kind: MongoDB
metadata:
  name: m2-sharded-cluster
  namespace: mongodb
spec:
  shardCount: 2
  mongodsPerShardCount: 3
  mongosCount: 1
  configServerCount: 1
  version: 4.2.3-ent
  opsManager:
    configMapRef:
      name: ops-manager-connection
  credentials: om-main-user-credentials
  type: ShardedCluster
  exposedExternally: true
  persistent: true
```

```bash
$ kubectl apply -f mongodb-m2-shardedcluster.yml
$ kubectl -n mongodb get mdb/m2-sharded-cluster -w

# wait until the Cluster is Running
NAME                 TYPE             STATE     VERSION     AGE
m2-sharded-cluster   ShardedCluster   Running   4.2.3-ent   5m55s

# verify statefulset
$ kubectl -n mongodb get statefulsets          
NAME                        READY   AGE
m2-sharded-cluster-0        3/3     7m1s
m2-sharded-cluster-1        3/3     5m32s
m2-sharded-cluster-config   1/1     7m31s
m2-sharded-cluster-mongos   1/1     3m56s
ops-manager                 1/1     3h22m
ops-manager-db              3/3     3h25m

# verify pods are running for the Cluster (mongos, config, shard1, shard2)
$ kubectl -n mongodb get pods
NAME                                           READY   STATUS    RESTARTS   AGE
m2-sharded-cluster-0-0                         1/1     Running   0          7m39s
m2-sharded-cluster-0-1                         1/1     Running   0          7m7s
m2-sharded-cluster-0-2                         1/1     Running   0          6m43s
m2-sharded-cluster-1-0                         1/1     Running   0          6m10s
m2-sharded-cluster-1-1                         1/1     Running   0          5m37s
m2-sharded-cluster-1-2                         1/1     Running   0          5m13s
m2-sharded-cluster-config-0                    1/1     Running   0          8m9s
m2-sharded-cluster-mongos-0                    1/1     Running   0          4m34s
mongodb-enterprise-operator-54ccddcd7f-rzbsd   1/1     Running   0          3h59m
ops-manager-0                                  1/1     Running   0          3h23m
ops-manager-db-0                               1/1     Running   0          3h26m
ops-manager-db-1                               1/1     Running   0          3h25m
ops-manager-db-2                               1/1     Running   0          3h24m
```

Since we enabled `spec.exposedExternally` we get a NodePort service for Mongos which we'll use to connect to the Sharded Cluster.

```bash
$ kubectl -n mongodb get service m2-sharded-cluster-svc-external
NAME                              TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE
m2-sharded-cluster-svc-external   NodePort   10.100.153.242   <none>        27017:32607/TCP   8m27s

```

### Teardown

```bash
__TODO__
```

### Nice commands to know

Set context to mongodb namespace

```bash
kube config set-context --current --namespace=mongodb
```

Install kubectl

```bash
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
```

### References

1. [EKS Workshop](https://eksworkshop.com/) - Tutorial on EKS
1. [Ops Manager in K8s](https://www.mongodb.com/blog/post/running-mongodb-ops-manager-in-kubernetes)
1. [Ops Manager Resource Docs](https://docs.mongodb.com/kubernetes-operator/v1.4/reference/k8s-operator-om-specification/)
1. [MongoDB Enterprise Kubernetes Operator](https://github.com/mongodb/mongodb-enterprise-kubernetes)
