output "vm_external_ip" {
  value = yandex_compute_instance.k8s.network_interface[0].nat_ip_address
}

output "vm_internal_ip" {
  value = yandex_compute_instance.k8s.network_interface[0].ip_address
}

output "ssh_command" {
  value = "ssh ubuntu@${yandex_compute_instance.k8s.network_interface[0].nat_ip_address}"
}

output "kubectl_command" {
  value = "ssh ubuntu@${yandex_compute_instance.k8s.network_interface[0].nat_ip_address} 'microk8s kubectl get nodes'"
}

