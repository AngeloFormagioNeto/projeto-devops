variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "app_name" {
  description = "Nome da aplicação"
  default     = "react-app"
}

variable "app_image" {
  description = "URL da imagem Docker"
  type        = string
}

variable "app_port" {
  description = "Porta do container"
  default     = 80
}

variable "app_count" {
  description = "Número de instâncias"
  default     = 1
}