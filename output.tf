output "public_ips" {
  value = ["${var.connections}"]

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "domain" {
  value = "${var.domain}"
}

output "api_port" {
  value = "${var.api_port}"
}

output "api_endpoints" {
  value = ["${formatlist("%s:%s", var.connections, var.api_port)}"]

  depends_on  = ["null_resource.primary", "null_resource.standby"]
}

output "overlay_cidr" {
  value = "${var.overlay_cidr}"
}

output "service_cidr" {
  value = "${var.service_cidr}"
}

output "kubernetes_version" {
  value = "${var.kubernetes_version}"
}

output "flannel_version" {
  value = "${var.flannel_version}"
}

output "kubeconfig" {
  value = "${data.null_data_source.kubernetes.outputs["kubeconfig"]}"
}

output "join_command" {
  value = "${data.external.join_command.result["command"]}"
}