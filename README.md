[![Join the chat at https://gitter.im/openshift/openshift-ansible](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/openshift/openshift-ansible)

#OpenShift Ansible by Turbonomic

##Whats Different from upstream
This repo creates openshift-origin that allows Master to start with 3rd party scheduler, to replace the default openshift scheduler,
and provide an advanced full-stack controller using kubeturbo.

##Prerequisites
1. Make sure you have Turbonomic instance installed and updated to version 47322, and reachable from Openshift cluster. You can use the following
offline update to upgrade your Turbonomic appliance.
SUSE: http://download.vmturbo.com/appliance/download/updates/5.6.3-Vegas-Containers/update64-47322-5.6.3_demo_containers.zip
RHEL: http://download.vmturbo.com/appliance/download/updates/5.6.3-Vegas-Containers/update64_redhat-47322-5.6.3_demo_containers.zip
2. Install Ansible
- Install base dependencies:
  - Fedora:
  ```
    dnf install -y ansible-2.1.0.0 pyOpenSSL python-cryptography
  ```
   - OSX:
  ```
    # Install ansible 2.1.0.0 and python 2
    brew install ansible python
  ```

##Setup openshift-origin using openshift-ansible
- Setup for a specific cloud:
  - [AWS](http://github.com/openshift/openshift-ansible/blob/master/README_AWS.md)
  - [GCE](http://github.com/openshift/openshift-ansible/blob/master/README_GCE.md)
  - [local VMs](http://github.com/openshift/openshift-ansible/blob/master/README_libvirt.md)

**NOTE: Add the following options into /etc/ansible/hosts, under [OSEv3:vars], before you run the playbook:**
openshift_node_kubelet_args={'config' : ['/etc/kubernetes/manifest']}

openshift_master_scheduler_args={'scheduler-name' : ['/etc/kubeturbo/kubeturbo.yml']}

- Bring your own host deployments:
  - [OpenShift Enterprise](https://docs.openshift.com/enterprise/latest/install_config/install/advanced_install.html)
  - [OpenShift Origin](https://docs.openshift.org/latest/install_config/install/advanced_install.html)
  - [Atomic Enterprise](http://github.com/openshift/openshift-ansible/blob/master/README_AEP.md)

**NOTE: Add the following options into /etc/ansible/hosts, under [OSEv3:vars], before you run the playbook:**
openshift_node_kubelet_args={'config' : ['/etc/kubernetes/manifest']}

openshift_master_scheduler_args={'scheduler-name' : ['/etc/kubeturbo/kubeturbo.yml']}

##Deploy Kubeturbo as Mirror Pod
1. Make sure openshift cluster is running by "oc get nodes"
2. Run post-installation.sh to deploy kubeturbo in your openshift cluster just deployed. You will be asked to provide:
   a. Turbonomic appliance IP with port number
   b. Turbonomic appliance Username
   c. Turbonomic appliance Password
3. Run oc get pods --all-namespaces -w to watch the kubeturbo pod deployment process.
4. Once kubeturbo starts running, you should be able to see the openshift cluster automatically regists itself to Turbonomic appliance
5. In order to enable the full-stack control, make sure you also added the underlying infrastructure targets to Turbonomic


##Misc
- Build
  - [How to build the openshift-ansible rpms](BUILD.md)

- Directory Structure:
  - [bin/cluster](https://github.com/openshift/openshift-ansible/tree/master/bin/cluster) - python script to easily create clusters
  - [docs](https://github.com/openshift/openshift-ansible/tree/master/docs) - Documentation for the project
  - [filter_plugins/](https://github.com/openshift/openshift-ansible/tree/master/filter_plugins) - custom filters used to manipulate data in Ansible
  - [inventory/](https://github.com/openshift/openshift-ansible/tree/master/inventory) - houses Ansible dynamic inventory scripts
  - [playbooks/](https://github.com/openshift/openshift-ansible/tree/master/playbooks) - houses host-type Ansible playbooks (launch, config, destroy, vars)
  - [roles/](https://github.com/openshift/openshift-ansible/tree/master/roles) - shareable Ansible tasks

##Contributing
- [Best Practices Guide](https://github.com/openshift/openshift-ansible/blob/master/docs/best_practices_guide.adoc)
- [Core Concepts](https://github.com/openshift/openshift-ansible/blob/master/docs/core_concepts_guide.adoc)
- [Style Guide](https://github.com/openshift/openshift-ansible/blob/master/docs/style_guide.adoc)
