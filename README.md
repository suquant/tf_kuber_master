# Kubernetes master service for terraform

## Features

* High availability mode with haproxy load balancer (module: tf_kuber_halb)
* Kube-router networks over wireguard vpn 

## Interfaces

### Input variables

* count - count of connections
* connections - public ips where applied
* private_ips - ips for communication
* cluster_domain -  (default: cluster.local)
* etcd_endpoints - (default: [])
* overlay_cidr - (default: 10.244.0.0/16)
* service_cidr - (default: 10.96.0.0/12)
* api_port - (default: 6443)
* kubernetes_version - (default: 1.12)
* kube_router_version - (default: v0.2.0)

### Output variables

* public_ips - public ips of instances/servers
* private_ips
* cluster_domain
* overlay_cidr
* service_cidr
* api_port
* kubernetes_version
* kube_router_version
* api_endpoints - api endpoints if multi master mode activated (count > 1)
* kubeconfig - admin kubeconfig
* join_command - join command for executo on worker(s) node(s)


## Example

```bash
terraform init
terraform apply -auto-approve > apply.log
```

```
variable "token" {}
variable "hosts" {
  default = 2
}
variable "overlay_cidr" {
  default = "10.244.0.0/16"
}

variable "docker_opts" {
  type = "list"
  default = [
    "--iptables=false",
    "--ip-masq=false",
    "--storage-driver=overlay2",
    "--live-restore",
    "--log-level=warn",
    "--bip=169.254.123.1/24",
    "--log-driver=json-file",
    "--log-opt=max-size=10m",
    "--log-opt=max-file=5",
    "--insecure-registry 10.0.0.0/8"
  ]
}

provider "hcloud" {
  token = "${var.token}"
}

module "provider" {
  source = "git::https://github.com/suquant/tf_hcloud.git?ref=v1.1.0"

  count = "${var.hosts}"

  server_type = "cx21"
}

module "wireguard" {
  source = "git::https://github.com/suquant/tf_wireguard.git?ref=v1.1.0"

  count         = "${var.hosts}"
  connections   = ["${module.provider.public_ips}"]
  private_ips   = ["${module.provider.private_ips}"]
  overlay_cidr  = "10.254.254.254/32"
}


module "etcd" {
  source = "git::https://github.com/suquant/tf_etcd.git?ref=v1.1.0"

  count       = "1"
  connections = ["${module.provider.public_ips[0]}"]

  hostnames   = ["${module.provider.hostnames[0]}"]
  private_ips = ["${module.wireguard.vpn_ips[0]}"]
}

module "docker" {
  source = "git::https://github.com/suquant/tf_docker.git?ref=v1.1.0"

  count       = "${var.hosts}"
  connections = ["${module.wireguard.public_ips}"]

  docker_opts = ["${var.docker_opts}"]
}

module "kuber_master" {
  source = "git::https://github.com/suquant/tf_kuber_master.git?ref=v1.1.0"

  count           = "${var.hosts}"
  connections     = ["${module.docker.public_ips}"]

  private_ips     = ["${module.wireguard.vpn_ips}"]
  etcd_endpoints  = "${module.etcd.client_endpoints}"
  overlay_cidr    = "${var.overlay_cidr}"
  node_labels     = [
    "node.example.com/key1=val1",
    "node.example.com/key2=val2"
  ]
}
```
