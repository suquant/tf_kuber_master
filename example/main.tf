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
  connections   = "${module.provider.public_ips}"
  private_ips   = "${module.provider.private_ips}"
}


module "etcd" {
  source = "git::https://github.com/suquant/tf_etcd.git?ref=v1.0.0"

  count       = "${var.hosts}"
  connections = "${module.provider.public_ips}"

  hostnames   = "${module.provider.hostnames}"
  private_ips = "${module.wireguard.ips}"
}

module "docker" {
  source = "git::https://github.com/suquant/tf_docker.git?ref=v1.0.0"

  count       = "${var.hosts}"
  # Fix of conccurent apt install running: will run only after wireguard has been installed
  connections = "${module.wireguard.public_ips}"

  docker_opts = ["${var.docker_opts}"]
}

module "kuber_master" {
  source = ".."

  count           = "${var.hosts}"
  connections     = ["${module.docker.public_ips}"]

  private_ips     = ["${module.provider.private_ips}"]
  etcd_endpoints  = "${module.etcd.client_endpoints}"
}