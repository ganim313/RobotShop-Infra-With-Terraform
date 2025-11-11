output "mysql_connection_name" {
  value = google_sql_database_instance.mysql.connection_name
}

output "redis_host" {
  value = google_redis_instance.redis.host
}

output "rabbitmq_url" {
  value = cloudamqp_instance.rabbitmq.url
}


