#!/bin/bash

set -e

#Version of cAdvisor
export CADVISOR_VERSION=v0.23.0

function gather_inputs {
	read -p "Enter the IP Address of Origin Master: " ORIGIN_MASTER_ADDRESS
	read -p "Enter the IP Address for Ops Manager: " SERVER_ADDRESS
	read -p "Enter Username for Ops Manager: " OPS_MANAGER_USERNAME
	read -s -p "Enter Password for Ops Manager: " OPS_MANAGER_PASSWORD
	echo
}

function init_templates {
    local TEMPLATE=/tmp/kubeturbo/turbo-user-service-account.yaml
    if [ ! -f $TEMPLATE ]; then
    	echo "TEMPLATE: $TEMPLATE"
    	mkdir -p $(dirname $TEMPLATE)
    	cat << EOF > $TEMPLATE
apiVersion: v1
kind: ServiceAccount
metadata:
  name: turbo-user
  namespace: default
EOF
    fi

# create cadvisor template.
    local TEMPLATE=/tmp/kubeturbo/cadvisor-daemonsets.yaml
    if [ ! -f $TEMPLATE ]; then
		echo "TEMPLATE: $TEMPLATE"
	    mkdir -p $(dirname $TEMPLATE)
	    cat << EOF > $TEMPLATE
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: default
  labels:
    name: cadvisor
spec:
  template:
    metadata:
      labels:
        name: cadvisor
    spec:
      containers:
      - name: cadvisor
        image: google/cadvisor:$CADVISOR_VERSION
        securityContext:
          privileged: true
        ports:
          - name: http
            containerPort: 8080
            hostPort: 9999
        volumeMounts:
          - name: rootfs
            mountPath: /rootfs
            readOnly: true
          - name: varrun
            mountPath: /var/run
            readOnly: false
          - name: varlibdocker
            mountPath: /var/lib/docker
            readOnly: true
          - name: sysfs
            mountPath: /sys
            readOnly: true
      serviceAccount: turbo-user
      volumes:
        - name: rootfs
          hostPath:
            path: /
        - name: varrun
          hostPath:
            path: /var/run
        - name: varlibdocker
          hostPath:
            path: /var/lib/docker
        - name: sysfs
          hostPath:
            path: /sys
EOF
	fi

# create turbo config.
	local TEMPLATE=/tmp/kubeturbo/config
    if [ ! -f $TEMPLATE ]; then
    	echo "TEMPLATE: $TEMPLATE"
    	mkdir -p $(dirname $TEMPLATE)
    fi
    	cat << EOF > $TEMPLATE
{
		"serveraddress": "$SERVER_ADDRESS:80",
		"targettype": "OpenShiftOrigin-$ORIGIN_MASTER_ADDRESS",
		"nameoraddress":  "openshift-origin",
		"username":"origin-user",
		"targetidentifier": "origin-cluster",
		"localaddress":"http://$ORIGIN_MASTER_ADDRESS/",
		"opsmanagerusername": "$OPS_MANAGER_USERNAME",
		"opsmanagerpassword": "$OPS_MANAGER_PASSWORD"
}
EOF

# create kubeturbo pod template.
    local TEMPLATE=/tmp/kubeturbo/kubeturbo.yaml
    if [ ! -f $TEMPLATE ]; then
		echo "TEMPLATE: $TEMPLATE"
	    mkdir -p $(dirname $TEMPLATE)
	    cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kubeturbo
  namespace: default
  labels:
    name: kubeturbo
spec:
  containers:
  - name: kubeturbo
    image: vmturbo/kubeturbo:1.1
    command:
      - /bin/kubeturbo
    args:
      - --v=3
      - --kubeconfig=/etc/kubeturbo/admin.kubeconfig
      - --etcd-servers=http://127.0.0.1:2379
      - --config-path=/etc/kubeturbo/config
      - --cadvisor-port=9999
    volumeMounts:
    - name: vmt-config
      mountPath: /etc/kubeturbo
      readOnly: true
  - name: etcd
    image: gcr.io/google_containers/etcd:2.0.9
    command:
    - /usr/local/bin/etcd
    - -data-dir
    - /var/etcd/data
    - -listen-client-urls
    - http://127.0.0.1:2379,http://127.0.0.1:4001
    - -advertise-client-urls
    - http://127.0.0.1:2379,http://127.0.0.1:4001
    - -initial-cluster-token
    - etcd-standalone
    volumeMounts:
    - name: etcd-storage
      mountPath: /var/etcd/data
  volumes:
  - name: etcd-storage
    emptyDir: {}
  - name: vmt-config
    hostPath:
      path: /etc/kubeturbo
  restartPolicy: Always
EOF
	fi

# create k8sconntrack daemonset template.
    local TEMPLATE=/tmp/kubeturbo/k8sconntrack-daemonset.yaml
    if [ ! -f $TEMPLATE ]; then
		echo "TEMPLATE: $TEMPLATE"
	    mkdir -p $(dirname $TEMPLATE)
	    cat << EOF > $TEMPLATE
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: k8snet
  namespace: default
  labels:
    name: k8snet
spec:
  template:
    metadata:
      labels:
        name: k8snet
    spec:
      hostNetwork: true
      containers:
      - name: k8sconntracker
        image: dongyiyang/k8sconntracker:dev
        securityContext:
          privileged: true
        ports:
          - name: http
            containerPort: 2222
            hostPort: 2222
        command:
          - /bin/conntracker
        args:
          - --v=3
          - --kubeconfig=/etc/kubeturbo/admin.kubeconfig
        volumeMounts:
        - name: turbo-config
          mountPath: /etc/kubeturbo
          readOnly: true
      restartPolicy: Always
      serviceAccount: turbo-user
      volumes:
      - name: turbo-config
        secret:
          secretName: turbo-config
EOF
	fi
}

function post_installation {
	local TARGET=/etc/kubeturbo
    if [ ! -d $TARGET ]; then
    	sudo mkdir -p $TARGET
    fi

    # copy turbo config to /etc/kubeturbo
    local TEMPLATE=/tmp/kubeturbo/config
    if [ ! -f $TEMPLATE ]; then
		echo "Cannot find config under /tmp/kubeturbo/. EXIT."
		exit
	fi
    sudo cp $TEMPLATE $TARGET/config
    echo "PLACED: $TARGET/config"

	# copy kubeconfig to /etc/kubeturbo
	local TEMPLATE=/etc/origin/master/admin.kubeconfig
    if [ ! -f $TEMPLATE ]; then
		echo "Cannot find admin.kubeconfig under /etc/origin/master/. EXIT."
		exit
	fi
	sudo cp $TEMPLATE /etc/kubeturbo/admin.kubeconfig
    echo "PLACED: $TARGET/admin.kubeconfig"

	oc create -f /tmp/kubeturbo/turbo-user-service-account.yaml
	oadm policy add-scc-to-user privileged system:serviceaccount:default:turbo-user
	oc create -f /tmp/kubeturbo/cadvisor-daemonsets.yaml

	oc create secret generic turbo-config --from-file=/etc/kubeturbo --namespace=default
	oc create -f /tmp/kubeturbo/k8sconntrack-daemonset.yaml

	# create manifest dir
	local TARGET=/etc/kubernetes/manifest
    if [ ! -d $TARGET ]; then
    	sudo mkdir -p $TARGET
    fi
    # copy turbo kubeturbo.yaml to /etc/kubernetes/manifest
    local TEMPLATE=/tmp/kubeturbo/kubeturbo.yaml
    if [ ! -f $TEMPLATE ]; then
		echo "Cannot find kubeturbo.yaml under /tmp/kubeturbo/. EXIT."
		exit
	fi
    sudo cp $TEMPLATE $TARGET/kubeturbo.yaml
    echo "PLACED: $TARGET/kubeturbo.yaml"

}

gather_inputs
init_templates
post_installation
