**Work in Progress**

## MongoDB on K8s

This repo shows how to demo the [MongoDB Enterprise Kubernetes Operator](https://docs.mongodb.com/kubernetes-operator/master/) on your MacBook using [Minikube](https://minikube.sigs.k8s.io/), [GKE](https://cloud.google.com/kubernetes-engine) and [EKS](https://aws.amazon.com/eks/).  The goal of this demo is to reinforce the Freedom to Run Anywhere by showing how easy it is to deploy, run and consume MongoDB on Kubernetes.

The MongoDB Enterprise Operator for Kubernetes allows devOps teams to:

* Deploy and run MongoDB Ops Manager on K8s infra
* Deploy and manage MongoDB Standalone, ReplicaSets and Sharded Clusters on K8s infra
* Benefit from K8s devOps goodness - extensibility, elasticity, resiliency...etc

Demo Guides

* [Local Box using Minikube](./LOCAL.md)
* [GKE](./GKE.md)
* [EKS](./EKS.md)

### References

1. [Ops Manager in K8s](https://www.mongodb.com/blog/post/running-mongodb-ops-manager-in-kubernetes)
1. [Ops Manager Resource Docs](https://docs.mongodb.com/kubernetes-operator/v1.4/reference/k8s-operator-om-specification/)
1. [MongoDB Enterprise Kubernetes Operator](https://github.com/mongodb/mongodb-enterprise-kubernetes)
