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
  default = "1.12"
}

variable "kubernetes_cni_version" {
  default = "0.6.0-00"
}

variable "kube_router_version" {
  default = "v0.2.0"
}

variable "node_labels" {
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

  provisioner "local-exec" {
    command = "${path.module}/scripts/sync_pki.sh"

    environment {
      src_host  = "${var.connections[0]}"
      dst_host  = "${element(var.connections, count.index + 1)}"
    }
  }

  provisioner "file" {
    content     = "${element(data.template_file.configuration.*.rendered, count.index + 1)}"
    destination = "/etc/kubernetes/configuration.yml"
  }

  provisioner "remote-exec" {
    inline = <<EOF
${data.template_file.init.rendered}
EOF
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
    etcd_endpoints      = "- ${join("\n  - ", split(",", var.etcd_endpoints))}"
    cert_sans           = "- ${join("\n  - ", concat(var.private_ips, list("127.0.0.1")))}"
    node_ip             = "${element(var.private_ips, count.index)}"
  }
}

data "template_file" "kube_router" {
  template = "${file("${path.module}/templates/kube-router.yml")}"

  vars {
    overlay_cidr        = "${var.overlay_cidr}"
    kube_router_version = "${var.kube_router_version}"
  }
}


data "template_file" "init" {
  template = "${file("${path.module}/templates/init.sh")}"

  vars {
    kubernetes_version = "${var.kubernetes_version}"
    node_labels        = "${join(" ", var.node_labels)}"
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