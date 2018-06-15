resource "null_resource" "primary" {
  depends_on = ["null_resource.install"]

  connection {
    host  = "${var.connections[0]}"
    user  = "root"
    agent = true
  }

  provisioner "file" {
    destination = "/etc/kubernetes/master-configuration.yml"
    content     = "${data.template_file.master_configuration.0.rendered}"
  }

  provisioner "file" {
    destination = "/etc/kubernetes/kube-flannel.yml"
    content     = "${data.template_file.kube_flannel.rendered}"
  }

  provisioner "remote-exec" {
    inline = <<EOF
${data.template_file.init.rendered}
EOF
  }

  # Install flannel
  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f /etc/kubernetes/kube-flannel.yml"
    ]
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
    content     = "${element(data.template_file.master_configuration.*.rendered, count.index + 1)}"
    destination = "/etc/kubernetes/master-configuration.yml"
  }

  provisioner "remote-exec" {
    inline = <<EOF
${data.template_file.init.rendered}
EOF
  }
}

data "template_file" "master_configuration" {
  count = "${var.count}"

  template = "${file("${path.module}/templates/master-configuration.yml")}"

  vars {
    count                   = "${var.count}"
    version                 = "${var.kubernetes_version}"
    domain                  = "${var.domain}"
    overlay_cidr            = "${var.overlay_cidr}"
    service_cidr            = "${var.service_cidr}"
    etcd_endpoints          = "- ${join("\n  - ", split(",", var.etcd_endpoints))}"
    cert_sans               = "- ${join("\n  - ", concat(var.private_ips, list("127.0.0.1")))}"
    api_advertise_addresses = "${element(var.private_ips, count.index)}"
  }
}

data "template_file" "kube_flannel" {
  template = "${file("${path.module}/templates/kube-flannel.yml")}"

  vars {
    version       = "${var.flannel_version}"
    overlay_cidr  = "${var.overlay_cidr}"
  }
}


data "template_file" "init" {
  template = "${file("${path.module}/templates/init.sh")}"

  vars {
    version = "${var.kubernetes_version}"
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