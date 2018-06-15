# Kubernetes master service for terraform

## Key features

* Scale master nodes without restart of whole cluster
* High availability mode with haproxy load balancer (module: tf_kuber_halb)
* Tiny and fast overlay network (flannel + wireguard extension) 

## Interfaces

### Input variables

* count - count of connections
* connections - public ips where applied
* private_ips - ips for communication
* domain -  (default: cluster.local)
* etcd_endpoints - (default: [])
* overlay_cidr - (default: 10.244.0.0/16)
* service_cidr - (default: 10.96.0.0/12)
* api_port - (default: 6443)
* kubernetes_version - (default: 1.10)
* flannel_version - (default: v0.10.0)

### Output variables

* public_ips - public ips of instances/servers
* domain
* overlay_cidr
* service_cidr
* api_port
* kubernetes_version
* flannel_version
* api_endpoints - api endpoints if multi master mode activated (count > 1)
* kubeconfig - admin kubeconfig
* join_command - join command for executo on worker(s) node(s)


## Example

```
variable "token" {}
variable "hosts" {
  default = 3
}

variable "docker_opts" {
  type = "list"
  default = ["--iptables=false", "--ip-masq=false"]
}

provider "hcloud" {
  token = "${var.token}"
}

module "provider" {
  source = "git::https://github.com/suquant/tf_hcloud.git?ref=v1.0.0"

  count = "${var.hosts}"
  token = "${var.token}"

  server_type = "cx21"
}

module "wireguard" {
  source = "git::https://github.com/suquant/tf_wireguard.git?ref=v1.0.0"

  count         = "${var.hosts}"
  connections   = ["${module.provider.public_ips}"]
  private_ips   = ["${module.provider.private_ips}"]
}


module "etcd" {
  source = "git::https://github.com/suquant/tf_etcd.git?ref=v1.0.0"

  count       = "${var.hosts}"
  connections = "${module.provider.public_ips}"

  hostnames   = "${module.provider.hostnames}"
  private_ips = ["${module.wireguard.ips}"]
}

module "docker" {
  source = "git::https://github.com/suquant/tf_docker.git?ref=v1.0.0"

  count       = "${var.hosts}"
  # Fix of conccurent apt install running: will run only after wireguard has been installed
  connections = ["${module.wireguard.public_ips}"]

  docker_opts = ["${var.docker_opts}"]
}

module "kuber_master" {
  source = ".."

  count           = "${var.hosts}"
  connections     = ["${module.docker.public_ips}"]

  private_ips     = ["${module.provider.private_ips}"]
  etcd_endpoints  = "${module.etcd.client_endpoints}"
}
```
