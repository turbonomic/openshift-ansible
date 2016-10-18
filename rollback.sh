#!/bin/bash

set -e

oc delete ds cadvisor
oc delete sa turbo-user
oc delete ds k8snet
oc delete secrets turbo-config

rm -rf /etc/kubeturbo
rm -rf /etc/kubernetes
rm -rf /tmp/kubeturbo