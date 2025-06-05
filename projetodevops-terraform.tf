# Configura o provedor da Vercel
provider "vercel" {
  api_token = var.vercel_token  
}

# Cria um projeto Vercel para aplicação React
resource "vercel_project" "projeto_devops" {
  name      = "projeto-devops"
  framework = "create-react-app" 

  git_repository = {
    type = "github"
    repo = "AngeloFormagioNeto/projeto-devops"  
  }

  # Configurações específicas para create-react-app
  build_command      = "npm run build"
  output_directory   = "build"  
  install_command    = "npm install" 

  # Domínio padrão
  domains = ["projeto-devops.vercel.app"]
}

# Configura variável de ambiente de produção
resource "vercel_project_environment_variable" "node_env" {
  project_id = vercel_project.projeto_devops.id
  key        = "NODE_ENV"
  value      = "production"
  target     = ["production"]  
}

# Saída com a URL do projeto
output "vercel_url" {
  value = vercel_project.projeto_devops.domain
}