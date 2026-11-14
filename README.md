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
- **Resumos com IA** — cada página de resultados gera automaticamente uma síntese central produzida por inteligência artificial, economizando tempo de leitura
- **Resumo individual de artigo** — qualquer artigo pode ser resumido por IA com um clique, com link compartilhável único
- **Autenticação segura** — cadastro com verificação de e-mail, login com cookie HttpOnly e recuperação de senha por link temporário
- **Interface mobile e web** — acesse pelo browser (React/Vite) ou pelo aplicativo Flutter (Android/iOS)
- **Painel administrativo** — métricas de temas pesquisados, gráficos de volume e gerenciamento de conexões de e-mail

---

## 🏛️ Arquitetura

### Back-end — microsserviços Node.js + Dart

O back-end usa arquitetura de microsserviços híbrida. As requisições entram pelo **Gateway Dart (porta 3100)**, que roteia para serviços Dart (auth, registro, recuperação, e-mail) ou repassa para o **Gateway Node.js (porta 3000)** via `LEGACY_BACKEND_URL` para os serviços de notícias e IA.

O gateway Node.js roteia internamente via **Event Service (porta 3007)** — barramento de eventos implementado manualmente.

| Serviço | Porta | Linguagem | Responsabilidade |
|---|---|---|---|
| Gateway Dart | 3100 | Dart | Entrada principal, CORS, roteamento híbrido |
| Gateway Node.js | 3000 | Node.js | Roteamento via event bus para news/AI/summaries |
| Auth Service | 3001 | Dart | Login, sessões JWT, cookies HttpOnly |
| Registration Service | 3003 | Dart | Cadastro, tokens de verificação, e-mail via NATS |
| AI Service | 3004 | Node.js | Completions OpenRouter, fallback de chaves/modelos |
| Email Service | 3005 | Dart | OAuth Gmail, envio via NATS JetStream |
| News Summary Service | 3006 | Node.js | Prompts de resumo central por página |
| Event Service | 3007 | Node.js | Barramento manual de eventos e service requests |
| Article Summary Service | 3008 | Node.js | Cache de resumos por URL, link compartilhável |
| News Service | 3002 | Node.js | Busca NewsAPI, histórico, métricas |
| Password Recovery Service | 3009 | Dart | Tokens de recuperação de senha via NATS |

### Front-end

| Interface | Tecnologia | Localização |
|---|---|---|
| Web | React + Vite + TypeScript | `frontend/` |
| Mobile | Flutter (Android / iOS) | `mobile/` |

### Banco de dados

PostgreSQL com isolamento por domínio. Os serviços Dart usam bancos separados (`auth_db`, `registration_db`, `password_recovery_db`, `email_db`). Os serviços Node.js compartilham o banco `portal_escarlate`.

### Mensageria

**NATS JetStream** — usado pelos serviços Dart para comunicação assíncrona entre Registration/Password Recovery e Email Service (padrão outbox → NATS → inbox).

### Integrações externas

- **NewsAPI.org** — busca de artigos reais
- **OpenRouter** — gateway de IA (suporte a GPT-4o, Claude, Llama, etc.)
- **Gmail API / Google OAuth** — envio de e-mails transacionais

---

## 🚀 Como executar

### Pré-requisitos

- Docker Desktop
- Flutter SDK ≥ 3.13 (para o app mobile)

### 1. Configurar variáveis de ambiente

```bash
cp .env.example .env
# Edite .env com suas credenciais
```

Variáveis obrigatórias no `.env`:

```env
AUTH_SECRET=<valor-aleatório>
PORTAL_INTERNAL_TOKEN=<valor-aleatório>
INTERNAL_SERVICE_TOKEN=<mesmo-valor-do-PORTAL_INTERNAL_TOKEN>
SECRETS_ENCRYPTION_KEY=<valor-aleatório>
PORTAL_DB_PASSWORD=<senha-do-postgres>
REGISTRATION_TOKEN_SECRET=<valor-aleatório-min-32-chars>
PASSWORD_RECOVERY_TOKEN_SECRET=<valor-aleatório-min-32-chars>
GOOGLE_CLIENT_ID=<seu-google-client-id>
GOOGLE_CLIENT_SECRET=<seu-google-client-secret>
APP_URL=http://localhost:5173
```

### 2. Subir o stack completo com Docker Compose

```bash
docker compose -f docker-compose.prod.yml up -d
```

Aguarde ~30 segundos. Para verificar que tudo subiu:

```bash
docker compose -f docker-compose.prod.yml ps
```

Todos os 18 containers devem mostrar `Up`.

### 3. Popular o banco (apenas na primeira vez)

**Usuário admin:**
```bash
# Banco Node.js
docker exec portal-escarlate-postgres-1 psql -U portal -d portal_escarlate -c \
  "INSERT INTO users_2 (email, password, role) VALUES ('admin@exemplo.com', '\$argon2id\$v=19\$m=19456,t=2,p=1\$DqIpCM7E1wU5as0gnr2pVg\$zRGefO2dFJo3QMkVkyLQwfkx1em/C1GYnfjfu4I3Vq8', 'admin');"

# Banco Dart (mesmas credenciais, banco separado)
docker exec portal-escarlate-postgres-1 psql -U portal -d auth_db -c \
  "INSERT INTO users_2 (email, password, role) VALUES ('admin@exemplo.com', '\$argon2id\$v=19\$m=19456,t=2,p=1\$DqIpCM7E1wU5as0gnr2pVg\$zRGefO2dFJo3QMkVkyLQwfkx1em/C1GYnfjfu4I3Vq8', 'admin');"
```

> A senha do exemplo acima é `Teste@123`. Para gerar um hash de outra senha:
> ```bash
> cd backend && node --input-type=module -e "import argon2 from 'argon2'; console.log(await argon2.hash('SuaSenha@123', {type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1}));"
> ```

**Chaves de API (NewsAPI e OpenRouter):**
```bash
docker exec portal-escarlate-postgres-1 psql -U portal -d portal_escarlate -c \
  "INSERT INTO news_api_keys (provider, api_key, active, priority) VALUES ('newsapi', 'SUA_CHAVE_NEWSAPI', true, 100);"

docker exec portal-escarlate-postgres-1 psql -U portal -d portal_escarlate -c \
  "INSERT INTO ai_api_keys (provider, label, api_key, active, priority) VALUES ('openrouter', 'Chave principal', 'SUA_CHAVE_OPENROUTER', true, 100) RETURNING id;"

# Use o UUID retornado acima
docker exec portal-escarlate-postgres-1 psql -U portal -d portal_escarlate -c \
  "INSERT INTO ai_models (api_key_id, model, active, priority) VALUES ('UUID-RETORNADO', 'openai/gpt-4o-mini', true, 100), ('UUID-RETORNADO', 'openai/gpt-3.5-turbo', true, 200);"
```

### 4. Conectar conta Gmail (para envio de e-mails)

1. Acesse `http://localhost:5173` no browser
2. Faça login com a conta admin
3. Vá em **Painel Admin → Conexões de E-mail → Conectar conta Google**
4. Autorize o acesso no Google

> O `GOOGLE_REDIRECT_URI` no `.env` deve ser `http://localhost:3100/api/google/callback`.  
> Adicione essa URI nas **Authorized redirect URIs** do seu app no Google Cloud Console.

### 5. Rodar o app Flutter (mobile)

```bash
cd mobile
flutter pub get

# Dispositivo físico Android (substitua pelo IP da sua máquina)
flutter run --dart-define=API_URL=http://SEU_IP:3100

# Emulador Android
flutter run --dart-define=API_URL=http://10.0.2.2:3100

# iOS Simulator
flutter run --dart-define=API_URL=http://localhost:3100
```

### 6. Parar o stack

```bash
docker compose -f docker-compose.prod.yml down
```

Para apagar também os dados do banco:
```bash
docker compose -f docker-compose.prod.yml down -v
```

---

## 🐳 Build das imagens Docker

### Imagem Node.js + Frontend

```bash
docker build -t portal-escarlate-node:latest .
```

### Imagens Dart

```bash
docker build -t portal-escarlate-dart:latest \
  --build-arg APP=api_gateway ./backend-dart

docker build -t portal-escarlate-dart-auth:latest \
  --build-arg APP=auth_service ./backend-dart

docker build -t portal-escarlate-dart-registration:latest \
  --build-arg APP=registration_service ./backend-dart

docker build -t portal-escarlate-dart-recovery:latest \
  --build-arg APP=password_recovery_service ./backend-dart

docker build -t portal-escarlate-dart-email:latest \
  --build-arg APP=email_service ./backend-dart
```

Ou use o `Makefile`:

```bash
make docker-build   # builda todas as imagens
make docker-up      # sobe o stack completo
make docker-down    # para o stack
```

---

## ☸️ Kubernetes (Minikube)

```bash
# Iniciar Minikube
minikube start --driver=docker

# Buildar e carregar imagens
make k8s-build

# Criar Secret com variáveis de ambiente
make k8s-secret

# Aplicar manifesto
kubectl apply -f kubernetes/portal-escarlate.yaml

# Verificar recursos
kubectl get pods,services

# Obter URLs dos serviços
make k8s-urls
```

**NodePorts expostos:**

| Serviço | NodePort |
|---|---|
| Frontend | 30080 |
| Gateway Node.js | 30000 |
| Gateway Dart | 30100 |

---

## 📁 Estrutura do repositório

```
Portal-Escarlate/
  backend/          Node.js — Gateway + microsserviços (news, AI, summaries, events)
  backend-dart/     Dart — microsserviços (Gateway, Auth, Registration, Email, Recovery)
  frontend/         React/Vite — interface web
  mobile/           Flutter — aplicativo Android/iOS
  kubernetes/       Manifesto Kubernetes completo
  scripts/          Scripts de build e inicialização
  Makefile          Atalhos para Docker e Kubernetes
  docker-compose.prod.yml  Stack de produção completo (18 containers)
  *.sql             Schemas de banco de dados por domínio
  Dockerfile        Build da imagem Node.js + frontend
  .env.example      Modelo de variáveis de ambiente
```

---

## 📜 Conventional Commits

Este repositório segue o padrão [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Exemplos de tipos usados:
- `feat(mobile):` nova tela ou integração no Flutter
- `feat(backend):` novo microsserviço ou funcionalidade
- `feat(infra):` Docker, Kubernetes, CI
- `fix:` correção de bug
- `docs:` atualização de documentação
- `chore:` tarefas de manutenção
