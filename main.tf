variable "count" {}

variable "connections" {
  type = "list"
}

variable "private_ips" {
  type = "list"
}

variable "cluster_domain" {
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
  default = "1.12.1"
}

variable "kubernetes_cni_version" {
  default = "0.6.0-00"
}

variable "kube_router_version" {
  default = "0.2.0"
}

variable "node_labels" {
  type = "list"
  default = []
}

variable "node_taints" {
  type = "list"
  default = []
}


resource "null_resource" "install" {
  count = "${var.count}"

  connection {
    host  = "${element(var.connections, count.index)}"
    user  = "root"
    agent = true
  }

  provisioner "file" {
    content     = "${data.template_file.apt_preference.rendered}"
    destination = "/etc/apt/preferences.d/kubernetes"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/ipv4_forward.conf",
      "echo 'net.bridge.bridge-nf-call-iptables=1' > /etc/sysctl.d/bridge_nf_call_iptables.conf",
      "sysctl -p",
      "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "echo \"deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-$$(lsb_release -cs) main\" > /etc/apt/sources.list.d/kubernetes.list",

      "apt update",
      "DEBIAN_FRONTEND=noninteractive apt install -yq kubelet kubeadm kubectl kubernetes-cni ipvsadm jq",
    ]
  }
}

resource "null_resource" "primary" {
  depends_on = ["null_resource.install"]

  connection {
    host  = "${var.connections[0]}"
    user  = "root"
    agent = true
  }

  provisioner "file" {
    destination = "/etc/kubernetes/configuration.yml"
    content     = "${data.template_file.configuration.0.rendered}"
  }

  provisioner "file" {
    destination = "/etc/kubernetes/kube-router.yml"
    content     = "${data.template_file.kube_router.rendered}"
  }

  provisioner "remote-exec" {
    inline = <<EOF
${data.template_file.init.rendered}
EOF
  }
}

resource "null_resource" "standby" {
  count = "${var.count - 1}"
  depends_on = ["null_resource.install", "null_resource.primary"]

  connection {
    host  = "${element(var.connections, count.index + 1)}"
    user  = "root"
    agent = true
  }

  provisioner "file" {
    content     = "${element(data.template_file.configuration.*.rendered, count.index + 1)}"
    destination = "/etc/kubernetes/configuration.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "rsync -apgo -e \"ssh -o StrictHostKeyChecking=no\" --include \"pki\" --include \"pki/ca.crt\" --include \"pki/ca.key\" --include \"pki/sa.crt\" --include \"pki/sa.key\" --include \"pki/front-proxy-ca.crt\" --include \"pki/front-proxy-ca.key\" --include \"admin.conf\" --exclude \"*\" root@${var.connections[0]}:/etc/kubernetes/ /etc/kubernetes/",
      "kubeadm alpha phase certs all --config /etc/kubernetes/configuration.yml",
      "kubeadm alpha phase kubelet config write-to-disk --config /etc/kubernetes/configuration.yml",
      "kubeadm alpha phase kubelet write-env-file --config /etc/kubernetes/configuration.yml",
      "kubeadm alpha phase kubeconfig kubelet --config /etc/kubernetes/configuration.yml",
      "systemctl daemon-reload && systemctl restart kubelet",

      "kubeadm alpha phase kubeconfig all --config /etc/kubernetes/configuration.yml",
      "kubeadm alpha phase controlplane all --config /etc/kubernetes/configuration.yml",
      "kubeadm alpha phase mark-master --config /etc/kubernetes/configuration.yml"
    ]
  }
}


data "template_file" "apt_preference" {
  template = "${file("${path.module}/templates/apt-preference.conf")}"

  vars {
    kubernetes_version      = "${var.kubernetes_version}"
    kubernetes_cni_version  = "${var.kubernetes_cni_version}"
  }
}


data "template_file" "configuration" {
  count = "${var.count}"

  template = "${file("${path.module}/templates/configuration.yml")}"

  vars {
    count               = "${var.count}"
    kubernetes_version  = "${var.kubernetes_version}"
    cluster_domain      = "${var.cluster_domain}"
    overlay_cidr        = "${var.overlay_cidr}"
    service_cidr        = "${var.service_cidr}"
    etcd_endpoints      = "${jsonencode(split(",", var.etcd_endpoints))}"
    cert_sans           = "${jsonencode(distinct(concat(var.private_ips, var.connections, list("127.0.0.1"))))}"
    node_ip             = "${element(var.private_ips, count.index)}"
    node_labels         = "${join(",", var.node_labels)}"
    node_taints         = "${join(",", var.node_taints)}"
  }
}

data "template_file" "kube_router" {
  template = "${file("${path.module}/templates/kube-router.yml")}"

  vars {
    overlay_cidr        = "${var.overlay_cidr}"
    kube_router_version = "v${var.kube_router_version}"
    node_taints         = "${indent(8, join("\n", data.template_file.node_taints.*.rendered))}"
  }
}


data "template_file" "init" {
  template = "${file("${path.module}/templates/init.sh")}"

  vars {
    kubernetes_version = "${var.kubernetes_version}"
  }
}

data "external" "kubeconfig" {
  depends_on = ["null_resource.primary"]

  program = ["sh", "${path.module}/scripts/get_kubeconfig.sh"]

  query = {
    host = "${var.connections[0]}"
  }
}

data "external" "join_command" {
  depends_on = ["null_resource.primary"]

  program = ["sh", "${path.module}/scripts/gen_join_command.sh"]

  query {
    host = "${var.connections[0]}"
  }
}

data "null_data_source" "kubernetes" {
  inputs {
    kubeconfig = "${base64decode(data.external.kubeconfig.result["content"])}"
  }
}

data "template_file" "node_taints" {
  count = "${length(var.node_taints)}"
  template = "- {\"key\": $${jsonencode(key)}, \"value\": $${jsonencode(val)}, \"effect\": $${jsonencode(effect)}}"

  vars {
    key    = "${element(split("=", element(var.node_taints, count.index)), 0)}"
    val    = "${element(split(":", element(split("=", element(var.node_taints, count.index)), 1)), 0)}"
    effect = "${element(split(":", element(split("=", element(var.node_taints, count.index)), 1)), 1)}"
  }
}



output "public_ips" {
  value = ["${var.connections}"]

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "private_ips" {
  value = ["${var.private_ips}"]

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "cluster_domain" {
  value = "${var.cluster_domain}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "api_port" {
  value = "${var.api_port}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "api_endpoints" {
  value = ["${formatlist("%s:%s", var.private_ips, var.api_port)}"]

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "overlay_cidr" {
  value = "${var.overlay_cidr}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "service_cidr" {
  value = "${var.service_cidr}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "kubernetes_version" {
  value = "${var.kubernetes_version}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "kubernetes_cni_version" {
  value = "${var.kubernetes_cni_version}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "kube_router_version" {
  value = "${var.kube_router_version}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "kubeconfig" {
  value = "${data.null_data_source.kubernetes.outputs["kubeconfig"]}"
}

output "join_command" {
  value = "${data.external.join_command.result["command"]}"
}

output "node_labels" {
  value = "${var.node_labels}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "node_taints" {
  value = "${var.node_labels}"

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}