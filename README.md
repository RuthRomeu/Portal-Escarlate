# Portal Escarlate

**Plataforma de notícias com inteligência artificial**  
Notícias, curadoria e tecnologia em uma experiência digital moderna.

---

## 👥 Integrantes da equipe

Em ordem alfabética:

| RA | Nome completo |
|---|---|
| 23.00768-0 | Enzo Pistori Fontenele |
| 23.01066-5 | Luigi de Lauand Botto |
| 23.00625-0 | Luigi de Menezes Collesi |
| 22.01003-3 | Ruth Ramos Romeu |

---

## 📱 Sobre o projeto

O Portal Escarlate é uma plataforma de notícias com inteligência artificial que permite ao usuário buscar, ler e compreender as principais notícias do mundo de forma mais rápida e inteligente. Em vez de navegar por dezenas de páginas dispersas, o usuário encontra tudo em um único lugar: resultados agregados de fontes confiáveis, resumos gerados por IA e histórico personalizado.

### O que o Portal Escarlate oferece?

- **Busca inteligente de notícias** — pesquise qualquer tema e receba artigos de fontes reais organizados e paginados, sem precisar sair do app
- **Resumos com IA** — cada página de resultados pode gerar um resumo central gerado por inteligência artificial, economizando tempo de leitura
- **Resumo individual de artigo** — qualquer artigo pode ser resumido por IA com um clique e compartilhado por link único
- **Autenticação segura** — cadastro com verificação de e-mail, login com cookie HttpOnly e recuperação de senha por link temporário
- **Interface mobile e web** — acesse pelo browser (React/Vite) ou pelo aplicativo Flutter (Android/iOS)
- **Painel administrativo** — métricas de temas pesquisados, gráficos de volume e gerenciamento de conexões de e-mail

---

## 🏛️ Arquitetura

### Back-end — microsserviços Node.js + Dart

O back-end usa arquitetura de microsserviços. Todas as requisições entram pelo **Gateway HTTP (porta 3000)**, que as roteia via **Event Service (porta 3007)** para o serviço responsável.

| Serviço | Porta | Linguagem | Responsabilidade |
|---|---|---|---|
| Gateway | 3000 | Node.js | Entrada única da API, CORS, roteamento |
| Auth Service | 3001 | Dart | Login, sessões JWT, cookies HttpOnly |
| News Service | 3002 | Node.js | Busca NewsAPI, histórico, métricas |
| Registration Service | 3003 | Dart | Cadastro, tokens de verificação, e-mail |
| AI Service | 3004 | **Dart** | Completions OpenRouter, fallback de chaves/modelos |
| News Summary Service | 3005 | Node.js | Prompts de resumo central por página |
| Email Service | 3006 | Dart | OAuth Gmail, envio de e-mails automáticos |
| Event Service | 3007 | Node.js | Barramento manual de eventos e service requests |
| Article Summary Service | 3008 | Node.js | Cache de resumos por URL, link compartilhável |
| Password Recovery Service | 3009 | Dart | Tokens de recuperação de senha |

### Front-end

| Interface | Tecnologia | Localização |
|---|---|---|
| Web | React + Vite + TypeScript | `frontend/` |
| Mobile | Flutter (Android / iOS) | `mobile/` |

### Banco de dados

PostgreSQL com isolamento por domínio — cada microsserviço usa suas próprias tabelas. Em desenvolvimento, um único banco compartilhado é suficiente.

### Integrações externas

- **NewsAPI.org** — busca de artigos reais
- **OpenRouter** — gateway de IA (suporte a GPT-4o, Claude, Llama, etc.)
- **Gmail API / Google OAuth** — envio de e-mails transacionais

---

## 🚀 Como executar

### Pré-requisitos

- Node.js ≥ 22
- Dart SDK ≥ 3.9
- Docker Desktop (opcional)
- Flutter SDK ≥ 3.13 (para o mobile)
- PostgreSQL 16+ (ou via Docker)

### 1. Configurar variáveis de ambiente

```bash
cp .env.example .env
# Edite .env com suas credenciais
```

### 2. Banco de dados

```bash
# Subir PostgreSQL via Docker
docker run -d --name portal-postgres \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=portal_escarlate -p 5432:5432 postgres:17-alpine

# Aplicar todos os schemas
for f in auth.sql registrar.sql password-recovery.sql email.sql news.sql ai.sql article-summary.sql; do
  docker exec -i portal-postgres psql -U postgres -d portal_escarlate < $f
done
```

### 3. Back-end (Node.js)

```bash
npm install
npm run dev --prefix backend   # Sobe todos os microsserviços Node.js
```

### 4. Front-end Web

```bash
npm run dev --prefix frontend  # http://localhost:5173
```

### 5. Aplicativo Flutter

```bash
cd mobile
flutter pub get
flutter run                    # Conecta em localhost:3000 (web/iOS)
                               # ou 10.0.2.2:3000 (Android Emulator)
```

### 6. Docker

```bash
docker build -t portal-escarlate:dev .
docker run --rm -p 5173:5173 \
  -v "$(pwd)/.env:/app/.env:ro" \
  -e NODE_ENV=development \
  -e FRONTEND_HOST=0.0.0.0 \
  portal-escarlate:dev
```

### 7. Kubernetes (Minikube)

```bash
minikube start --driver=docker
docker build -t portal-escarlate:dev .
minikube image load portal-escarlate:dev
kubectl create secret generic portal-escarlate-env --from-file=.env=.env
kubectl apply -f kubernetes/portal-escarlate.yaml
minikube service portal-escarlate --url
```

---

## 🔑 Configurar chave da IA (OpenRouter)

A chave não fica no `.env` — ela é armazenada cifrada no banco de dados:

```sql
-- Inserir chave de API
INSERT INTO ai_api_keys (provider, label, api_key, active, priority)
VALUES ('openrouter', 'Chave principal', 'sk-or-v1-SUA-CHAVE', true, 100)
RETURNING id;

-- Vincular modelos à chave (use o UUID retornado acima)
INSERT INTO ai_models (api_key_id, model, active, priority) VALUES
  ('UUID-DA-CHAVE', 'openai/gpt-4o-mini', true, 100),
  ('UUID-DA-CHAVE', 'openai/gpt-3.5-turbo', true, 200);
```

---

## 📁 Estrutura do repositório

```
Portal-Escarlate/
  backend/          Node.js — Gateway + microsserviços
  backend-dart/     Dart — microsserviços Auth, Registration, Email, AI, Password Recovery
  frontend/         React/Vite — interface web
  mobile/           Flutter — aplicativo Android/iOS
  kubernetes/       Manifesto Kubernetes
  scripts/          Scripts de build e inicialização
  *.sql             Schemas de banco de dados por domínio
  Dockerfile        Build da imagem de produção
  .env.example      Modelo de variáveis de ambiente
```

---

## 📜 Conventional Commits

Este repositório segue o padrão [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Exemplos de tipos usados:
- `feat(backend):` novo microsserviço ou funcionalidade
- `feat(frontend):` nova tela ou componente
- `fix:` correção de bug
- `docs:` atualização de documentação
- `chore:` tarefas de infraestrutura (Docker, CI, deps)
