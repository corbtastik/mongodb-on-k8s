## MongoDB DIY on K8s

### Setup

1. Create local storage folder on Worker Node
1. Replace Node Selector to suit your K8s env

```yaml
# mongodb-persistent-volume.yml and mongodb-statefulset.yml
spec:
  nodeSelector:
    kubernetes.io/hostname: kubeone # node selected must have local storage
```

### Deploy Standalone

```bash
./provision.sh
```

### Connect to Container Instance

```bash
mongo "mongodb://INTERNAL-IP:NODE-PORT" --authenticationDatabase=admin --username=main_user
use todosdb
db.createCollection('todos')
db.todos.save({title: 'Make bacon pancakes', complete: true})
db.todos.save({title: 'Eat bacon pancakes', complete: false})
db.todos.save({title: 'Clean up kitchen', complete: false})
db.todos.find({complete: true})
```

### Teardown

```bash
./teardown.sh
```
