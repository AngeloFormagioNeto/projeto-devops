variable "vercel_api_token" {
  type        = string
  description = "Vercel API Token"
  sensitive   = true
}

variable "docker_image" {
  type        = string
  description = "Docker image to deploy"
}

variable "project_name" {
  type        = string
  description = "Vercel project name"
  default     = "my-react-app"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in format owner/repo"
}

terraform {
  required_providers {
    vercel = {
      source  = "vercel/vercel"
      version = "~> 1.0"
    }
  }
}

provider "vercel" {
  api_token = var.vercel_api_token
}

resource "vercel_project" "app" {
  name      = var.project_name
  framework = "docker"

  git_repository = {
    type = "github"
    repo = var.github_repo
  }
}

resource "vercel_deployment" "app" {
  project_id = vercel_project.app.id
  files = {
    "vercel.json" = jsonencode({
      builds = [{
        src     = "Dockerfile"
        use     = "@vercel/docker"
        config = {
          dockerfile = "Dockerfile"
        }
      }]
      routes = [
        {
          src       = "/(.*)"
          dest      = "/$1"
          methods   = ["GET"]
          continue  = true
        }
      ]
    })
  }

  environment = {
    DOCKER_IMAGE = var.docker_image
  }
}

output "vercel_url" {
  value = "https://${vercel_deployment.app.url}"
}