
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

* Create a namespace for all MongoDB assets.

```bash
kube create namespace mongodb
```

Create Custom Resource Definitions

* MongoDB
* MongoDBUser
* MongoDBOpsManager

```bash
# Download Custom Resource Definitions
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml
# Download MongoDB Enterprise Operator
curl -O https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml
```

### Deploy MongoDB Kubernetes Operator

```bash
kube create secret generic ops-manager-admin-secret \
--from-literal=Username="corbett.martin@mongodb.com" \
--from-literal=Password="Passw0rd." \
--from-literal=FirstName="Corbett" \
--from-literal=LastName="Martin" \
-n mongodb
```

### Ops Manager User

```txt
# User > Account > Public API Access > Generate
-------------------------------------------------
Description: om-main-user-credentials
API Key:     0b0b0759-f180-4bd5-8251-98f8498dcfee
```

```bash
kube create secret generic om-main-user-credentials \
  --from-literal="user=corbett.martin@mongodb.com" \
  --from-literal="publicApiKey=0b0b0759-f180-4bd5-8251-98f8498dcfee" \
  -n mongodb
```

```bash
kube create configmap ops-manager-connection \
  --from-literal="baseUrl=http://ops-manager-svc.mongodb.svc.cluster.local:8080" \
  --from-literal="projectName=Project0" \
  -n mongodb
```

### Teardown




























### References
