#!/bin/bash

# gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project braden-istio
# kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)

# https://istio.io/docs/setup/kubernetes/quick-start.html

export PATH=$PWD/bin:$PATH

minikube start \
  --vm-driver hyperkit \
  --kubernetes-version=v1.7.5 \
  --extra-config=apiserver.Authorization.Mode=RBAC \
  --extra-config=apiserver.Admission.PluginNames="Initializers,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,GenericAdmissionWebhook,ResourceQuota" \
  --memory 10240 \
  --disk-size 30g 

#  --feature-gates=AllAlpha=true \

# Install Istio
kubectl apply -f install/kubernetes/istio.yaml || kubectl apply -f install/kubernetes/istio.yaml
# OR kubectl apply -f install/kubernetes/istio-auth.yaml # also enable mutual TLS authentication

# Automagic Sidecar injection
kubectl apply -f install/kubernetes/istio-initializer.yaml || kubectl apply -f install/kubernetes/istio-initializer.yaml

kubectl apply -n istio-system -f https://raw.githubusercontent.com/jaegertracing/jaeger-kubernetes/master/all-in-one/jaeger-all-in-one-template.yml

kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=jaeger -o jsonpath='{.items[0].metadata.name}') 16686:16686 &



# Sample Application
kubectl apply -f samples/bookinfo/kube/bookinfo.yaml || kubectl apply -f samples/bookinfo/kube/bookinfo.yaml
# Without auto-injection: kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/kube/bookinfo.yaml)
