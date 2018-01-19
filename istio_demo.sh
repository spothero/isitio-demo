#!/bin/bash


##############################################################################################
##############################################################################################
##############################################################################################
# brew install doitlive
# Run via: `doitlive play istio_demo.sh -s 999`
# In ~/.bash_profile
#   export PATH=~/istio-example/istio-0.4.0/bin:$PATH
#   export ISTIO_PATH=istio-0.4.0
PROJECT_NAME=braden-istio
CLUSTER_NAME=cluster-1

##############################################################################################
################################ Install & Setup #############################################
##############################################################################################
## https://istio.io/docs/setup/kubernetes/quick-start.html
## https://istio.io/docs/guides/bookinfo.html
## Notes: Create cluster with alpha features enabled in GKE

gcloud container clusters get-credentials $CLUSTER_NAME --zone us-central1-a --project $PROJECT_NAME
kubectl config get-contexts
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)

# Install Istio
kubectl apply -f $ISTIO_PATH/install/kubernetes/istio.yaml 
# OR kubectl apply -f $ISTIO_PATH/install/kubernetes/istio-auth.yaml # also enable mutual TLS authentication

# Automagic Sidecar injection
kubectl apply -f $ISTIO_PATH/install/kubernetes/istio-initializer.yaml

# Sample Application
kubectl apply -f $ISTIO_PATH/samples/bookinfo/kube/bookinfo.yaml
# Without auto-injection: kubectl apply -f <(istioctl kube-inject -f $ISTIO_PATH/samples/bookinfo/kube/bookinfo.yaml)

##############################################################################################
############################# Routing ########################################################
##############################################################################################
kubectl get ingress -o wide  | grep gateway | awk '{printf "%s:%s/productpage",$3,$4;}'

# Route all to v1
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-all-v1.yaml
istioctl get routerules -o yaml

# Route 1/2 traffic to v3
istioctl replace -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-50-v3.yaml
istioctl get routerules -o yaml

# Route all traffic to v3
istioctl replace -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-v3.yaml
istioctl get routerules -o yaml

# Content based routing
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-test-v2.yaml
istioctl get routerule reviews-test-v2 -o yaml

# Cleanup
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-all-v1.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-test-v2.yaml
istioctl get routerules -o yaml

##############################################################################################
################################## Fault injection ###########################################
##############################################################################################
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-all-v1.yaml
istioctl replace -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-v2.yaml
istioctl replace -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-ratings-2sec-delay.yaml
istioctl replace -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-1sec-timeout.yaml
istioctl get routerule -o yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-all-v1.yaml

istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-all-v1.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-test-v2.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-ratings-test-delay.yaml
istioctl get routerule ratings-test-delay -o yaml

istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-all-v1.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-test-v2.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-ratings-test-delay.yaml

##############################################################################################
############################ Security ########################################################
##############################################################################################
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-test-v2.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-v3.yaml
cat $ISTIO_PATH/samples/bookinfo/kube/whitelist-handler.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/whitelist-handler.yaml
cat $ISTIO_PATH/samples/bookinfo/kube/appversion-instance.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/appversion-instance.yaml
cat $ISTIO_PATH/samples/bookinfo/kube/checkversion-rule.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/checkversion-rule.yaml

istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/whitelist-handler.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/appversion-instance.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/checkversion-rule.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-test-v2.yaml
istioctl delete -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-reviews-v3.yaml

##############################################################################################
################################# Tracing, Metrics, Logging ##################################
##############################################################################################
# Install Jaeger
kubectl apply -n istio-system -f https://raw.githubusercontent.com/jaegertracing/jaeger-kubernetes/master/all-in-one/jaeger-all-in-one-template.yml
echo "http://localhost:16686"

# Install Prometheus
kubectl apply -f $ISTIO_PATH/install/kubernetes/addons/prometheus.yaml
echo "http://localhost:9090/graph"

cat $ISTIO_PATH/new_telemetry_metrics.yaml
istioctl create -f $ISTIO_PATH/new_telemetry_metrics.yaml

cat $ISTIO_PATH/new_telemetry_logs.yaml
istioctl create -f $ISTIO_PATH/new_telemetry_logs.yaml

# TCP Stats
cat $ISTIO_PATH/tcp_telemetry.yaml
istioctl create -f $ISTIO_PATH/tcp_telemetry.yaml
kubectl apply -f $ISTIO_PATH/samples/bookinfo/kube/bookinfo-ratings-v2.yaml
kubectl apply -f $ISTIO_PATH/samples/bookinfo/kube/bookinfo-db.yaml
istioctl create -f $ISTIO_PATH/samples/bookinfo/kube/route-rule-ratings-db.yaml
# Command to show route
istioctl get routerules -o yaml

# Grafana
kubectl apply -f $ISTIO_PATH/install/kubernetes/addons/grafana.yaml
echo "http://localhost:3000/dashboard/db/istio-dashboard"

##############################################################################################
############################### Pretty Picture ###############################################
##############################################################################################
kubectl apply -f $ISTIO_PATH/install/kubernetes/addons/servicegraph.yaml
echo "http://localhost:8088/dotviz"
