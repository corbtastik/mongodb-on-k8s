## Minikube

__step-0__

```bash
# modify start.sh to your taste
./start.sh
```

## MongoDB Community

### Deploy Standalone

```bash
kube create secret generic mongodb-admin-creds \
  --from-literal=username=main_user \
  --from-literal=password=howdy
kube apply -f mongodb-statefulset.yml
kube apply -f mongodb-clusterip.yml
```

### Connect to Container Instance

```bash
kubectl exec -it mongodb-standalone-0 sh
mongo admin -u main_user
use todosdb
db.createCollection('todos')
db.todos.save({title: 'Make bacon pancakes', complete: true})
db.todos.save({title: 'Eat bacon pancakes', complete: false})
db.todos.save({title: 'Clean up kitchen', complete: false})
db.todos.find({complete: true})
```

### Connect from local machine

```bash
kube apply -f mongodb-nodeport.yml
kube get nodes -o wide # get INTERNAL-IP
kube get service mongodb-nodeport -o wide # get NODE-PORT
mongo "mongodb://INTERNAL-IP:NODE-PORT" --authenticationDatabase=admin --username=main_user
```

### Deploy standalone with external volume

```bash
kube create secret generic mongodb-admin-creds --from-literal=username=main_user --from-literal=password=howdy
kube apply -f mongodb-storageclass.yml
kube apply -f mongodb-persistent-volume.yml
kube apply -f mongodb-statefulset-local.yml
kube apply -f mongodb-clusterip.yml
kube apply -f mongodb-nodeport.yml
```

---

The MongoDB Enterprise Operator for Kubernetes allows devOps teams to:

* Deploy and run MongoDB Ops Manager on K8s  
* Deploy MongoDB clusters on K8s  

### Initial setup

__step-1__

* Create a namespace for all MongoDB assets.

```bash
kube create namespace mongodb
```

__step-2__

Create Custom Resource Definitions

* MongoDB
* MongoDBUser
* MongoDBOpsManager

```bash
# Download Custom Resource Definitions
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
kube apply -f crds.yaml
# Download MongoDB Enterprise Operator
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
kube apply -f mongodb-enterprise.yaml
```

### Deploy MongoDB Kubernetes Operator

__step-3__

```bash
kube create secret generic ops-manager-admin-secret \
--from-literal=Username="opsman.admin@mongodb.com" \
--from-literal=Password="Passw0rd." \
--from-literal=FirstName="Ops" \
--from-literal=LastName="Manager" \
-n mongodb
```

__step-4__

Deploy MongoDB Ops Manager in a Pod as well as a 3 member MongoDB ReplicaSet for the Ops Manager application database.  Each startup time we vary based on Hardware and quota given to Minikube, however expect to wait 5-10 mins for everything to reach Running status.

If you're on a macbook you'll know its working because the fans should be spinning.

```bash
kube apply -f mongodb-ops-manager-1.yml
# wait a few mins for the objects to create
kube -n mongodb get om -w
# should have these objects
kube -n mongodb get pods -o wide  
NAME                        READY  STATUS             RESTARTS  AGE
mongodb-enterprise-operator 1/1    Running            0         62m
ops-manager-0               1/1    Running            0         7m3s
ops-manager-db-0            1/1    Running            0         9m20s
ops-manager-db-1            1/1    Running            0         8m24s
ops-manager-db-2            1/1    Running            0         7m48s
```

[Ops Manager Resource Docs](https://docs.mongodb.com/kubernetes-operator/v1.4/reference/k8s-operator-om-specification/)
[MongoDB Enterprise Kubernetes Operator](https://github.com/mongodb/mongodb-enterprise-kubernetes)

__step-5__

Open MongoDB Ops Manager and login with the `ops-manager-admin-secret` creds above.  To get the right endpoint for Ops Manager retrieve the node's INTERNAL-IP and NodePort.

```bash
# remember INTERNAL-IP
kube -n mongodb get node -o wide
# remember high-side NODE-PORT, should be something like 3xxxx
kube -n mongodb get service ops-manager-svc-ext
```

Open a Browser to http://INTERNAL-IP:NODE-PORT

![Ops Manager Login](/assets/OpsManagerLogin.png)

__step-6__

Remove the `ops-manager-admin-secret` secret from Kubernetes because you remember it right?

```bash
kube delete secret ops-manager-admin-secret -n mongodb
```

__step-7__

Walk through the Ops Manager setup, accepting the defaults.  Once complete you'll have an Ops Manager almost ready to deal.

![Ops Manager Login](/assets/OpsManagerOverview.png)

### Create

### Ops Manager User

__step-8__

```txt
# User > Account > Public API Access > Generate
-------------------------------------------------
Description: om-main-user-credentials
API Key:     0495b741-3aef-40d7-9ba0-5f3b96085c9c
```

```bash
kube create secret generic om-main-user-credentials \
  --from-literal="user=corbett.martin@mongodb.com" \
  --from-literal="publicApiKey=0495b741-3aef-40d7-9ba0-5f3b96085c9c" \
  -n mongodb
```

__step-9__

```bash
kube create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb
```

__step-10__

```bash
kube apply -f mongodb-m0-standalone.yaml
# or kube apply -f mongodb-replicaset.yml
# or kube apply -f mongodb-shared.yml
# wait for the 3 node replicaset to come up...
kube get mdb -n mongodb -w
```

### Teardown

```bash
kube delete pvc mongodb-standalone
kube delete pv mongodb-standalone
kube delete namespace mongodb
kube delete storageclass mongodb-standalone
kube delete crd mongodb.mongodb.com
kube delete crd mongodbusers.mongodb.com
kube delete crd opsmanagers.mongodb.com

kube delete secret mongodb-admin-creds
kube delete secret ops-manager-admin-secret
kube delete secret ops-manager-admin-secret

```













### Nice commands to know

```bash
kube config set-context --current --namespace=mongodb
```

```bash
r=https://api.github.com/repos/machine-drivers/docker-machine-driver-vmware
curl -LO $(curl -s $r/releases/latest | grep -o 'http.*darwin_amd64' | head -n1) \
 && install docker-machine-driver-vmware_darwin_amd64 \
  /usr/local/bin/docker-machine-driver-vmware
```















### References

1. [Ops Manager in K8s](https://www.mongodb.com/blog/post/running-mongodb-ops-manager-in-kubernetes)
