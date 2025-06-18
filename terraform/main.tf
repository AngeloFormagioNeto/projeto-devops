terraform {
  required_providers {
    netlify = {
      source  = "netlify/netlify"
      version = "~> 3.0"
    }
  }
}

provider "netlify" {
  token = var.netlify_token
}

resource "netlify_site" "react_app" {
  name = "meu-app-react-${var.environment}"

  build_settings {
    base_dir    = "build"
    deploy_dir  = "build"
  }
}

resource "netlify_deploy" "production" {
  site_id = netlify_site.react_app.id
  dir     = "${path.root}/../build"
}