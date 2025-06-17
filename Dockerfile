# Estágio de construção (build)
FROM node:18-alpine AS builder
WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências
RUN npm ci

# Copiar todo o código fonte
COPY . .

# Construir a aplicação
RUN npm run build

# ----------------------------------------

# Estágio de produção (servidor web leve)
FROM nginx:stable-alpine

# Copiar os arquivos buildados do estágio anterior
COPY --from=builder /app/build /usr/share/nginx/html

# Copiar configuração customizada do Nginx (opcional)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expor a porta 80 (porta padrão do Nginx)
EXPOSE 80

# Comando para iniciar o Nginx
CMD ["nginx", "-g", "daemon off;"]