variable "count" {}

variable "connections" {
  type = "list"
}

variable "private_ips" {
  type = "list"
}

variable "domain" {
  default = "cluster.local"
}

variable "etcd_endpoints" {}

variable "overlay_cidr" {
  default = "10.244.0.0/16"
}

variable "service_cidr" {
  default = "10.96.0.0/12"
}

variable "api_port" {
  default = "6443"
}

variable "kubernetes_version" {
  default = "1.10"
}

variable "flannel_version" {
  default = "v0.10.0"
}