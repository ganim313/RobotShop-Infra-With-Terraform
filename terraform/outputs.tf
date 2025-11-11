output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "bastion_host_ip" {
  value = length(google_compute_instance.bastion-host.network_interface[0].access_config) > 0 ? google_compute_instance.bastion-host.network_interface[0].access_config[0].nat_ip : ""
}

output "mysql_connection_name" {
  value = module.databases.mysql_connection_name
}

output "redis_host" {
  value = module.databases.redis_host
}

output "rabbitmq_url" {
  value = module.databases.rabbitmq_url
  sensitive = true
}

output "mongodb_srv_address" {
  value = mongodbatlas_cluster.robot_shop_mongo.srv_address
}
