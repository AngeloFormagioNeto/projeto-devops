terraform {
  required_version = ">= 1.0.0"

  required_providers {
    netlify = {
      source  = "netlify/netlify"
      version = "3.4.1"
    }
  }
}