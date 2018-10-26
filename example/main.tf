variable "token" {}
variable "hosts" {
  default = 1
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

  server_type = "cx11"
}

module "wireguard" {
  source = "git::https://github.com/suquant/tf_wireguard.git?ref=v1.1.0"

  count         = "${var.hosts}"
  connections   = ["${module.provider.public_ips}"]
  private_ips   = ["${module.provider.private_ips}"]
  overlay_cidr  = "10.254.254.254/32"
}


module "etcd" {
  source = "/Users/georgy/workspace/github.com/suquant/tf_etcd"

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
  source = ".."

  count           = "${var.hosts}"
  connections     = ["${module.docker.public_ips}"]

  private_ips     = ["${module.wireguard.vpn_ips}"]
  etcd_endpoints  = "${module.etcd.client_endpoints}"
  overlay_cidr    = "${var.overlay_cidr}"
}
