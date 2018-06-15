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
    inline = <<EOF
${data.template_file.install.rendered}
EOF
  }
}

data "template_file" "apt_preference" {
  template = "${file("${path.module}/templates/apt-preference.conf")}"

  vars {
    version = "${var.kubernetes_version}"
  }
}

data "template_file" "install" {
  template = "${file("${path.module}/templates/install.sh")}"

  vars {
    version = "${var.kubernetes_version}"
  }
}