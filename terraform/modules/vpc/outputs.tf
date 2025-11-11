output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "public_subnet_id" {
  value = google_compute_subnetwork.public.id
}

output "private_subnet_id" {
  value = google_compute_subnetwork.private.id
}

output "private_subnet_cidr" {
  value = google_compute_subnetwork.private.ip_cidr_range
}

output "service_networking_connection_id" {
  value = google_service_networking_connection.private_vpc_connection.id
}

output "nat_gateway_ip" {
  value = google_compute_address.nat.address
}