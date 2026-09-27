# 🔴 Portal Escarlate – Plataforma Inteligente de Análise de Notícias

## 👥 Integrantes
- Enzo Pistori Fontenele de Oliveira - 23.00768-0
- Luigi de Menezes Collesi - 23.00625-0
- Luigi de Lauand Botto - 23.01066-5
- Ruth Ramos Romeu - 22.01003-3

## 📌 Descrição do Projeto
O Portal Escarlate é uma plataforma web que tem como objetivo central oferecer uma forma mais inteligente, organizada e crítica de consumir notícias.
A aplicação visa permitir que usuários acessem notícias relevantes com o diferencial de utilizar inteligência artificial para processamento de conteúdo e cruzar dados públicos de agentes políticos. O estágio atual do sistema foca na base estrutural de microsserviços, segurança e comunicação assíncrona para suportar essas futuras integrações.

## 🚀 Funcionalidades Atuais
- Cadastro, autenticação e exclusão autônoma de usuários
- Sessões dinâmicas com controle temporizado de expiração de acesso (JWT)
- Rotas protegidas no Front-End
- Captura de eventos do sistema (criação, login e exclusão de contas) via Barramento
- Persistência de dados em nuvem com Supabase

## 🛠️ Tecnologias e Arquitetura
O projeto está sendo desenvolvido utilizando o padrão de **Microsserviços**, garantindo que cada domínio da aplicação seja independente e escalável.
- **Front-End:** Next.js (App Router), NextAuth (Sessões JWT via Cookies) e Axios.
- **Back-End (Auth):** Node.js, Express, BcryptJS (Hash de senhas) e Supabase (PostgreSQL em nuvem).
- **Comunicação:** Barramento de Eventos interno para comunicação assíncrona entre os microsserviços.

## ⚙️ Como executar o projeto localmente
**1. Configuração do Banco de Dados**
O projeto utiliza o Supabase como banco de dados em nuvem. Crie um projeto na plataforma Supabase e rode o script localizado em `back/servico-auth/schema.sql` no editor SQL deles para criar as tabelas necessárias.

**2. Variáveis de Ambiente (.env)**

Crie um arquivo `.env` na raiz do projeto utilizando `.env.example` como referência.

**3. Inicialização dos Serviços**
Abra terminais distintos para cada serviço e execute:
- **Barramento:** `node index.js` (Porta 10000)
- **Serviço de Auth:** `node index.js` (Porta 4000)
- **Front-End:** `npm run dev` (Porta 3000)

### Execução com Docker

Crie a imagem Docker:

```bash
docker build -t portal-escarlate:dev .
```

Execute a aplicação localmente:

```bash
docker run \
  --rm \
  --name portal-escarlate-local \
  -p "127.0.0.1:5173:5173" \
  -v "$(pwd)/.env:/app/.env:ro" \
  -e NODE_ENV="development" \
  -e APP_URL="http://localhost:5173" \
  -e FRONTEND_HOST="0.0.0.0" \
  -e FRONTEND_PORT="5173" \
  -e VITE_API_URL="http://127.0.0.1:3000" \
  portal-escarlate:dev
```

Acesse a aplicação em:

```text
http://localhost:5173
```