output "alb_dns_name" {
  value       = aws_lb.app.dns_name
  description = "DNS do Application Load Balancer"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Nome do cluster ECS"
}