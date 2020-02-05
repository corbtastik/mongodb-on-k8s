## MongoDB DIY on K8s

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
