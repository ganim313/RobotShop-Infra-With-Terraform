output "node_pool_service_account" {
  value = google_service_account.gke_nodepool_sa.email
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}
