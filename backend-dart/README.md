# Portal Escarlate — Backend Dart (fundação)

Base técnica **aditiva**. O backend Node.js (`../backend`) e o React (`../frontend`)
continuam inalterados. Nenhum endpoint de negócio foi migrado.

## Componentes

- Gateway HTTP síncrono: porta **3100**. Preserva as rotas públicas do Node
  (`/api/auth/login`, `/api/auth/register/request`, etc.), encaminhando diretamente
  para os respectivos serviços HTTP. O NATS NÃO atua como proxy.
- Oito microsserviços com endpoint `GET /health/live` e isolamento por token
  interno para demais rotas.
- `portal_events`: JetStream durável para eventos **internos**.
- `portal_database`: driver PostgreSQL, pool e transações (sem tabelas).
- `portal_external_api`: cliente HTTP JSON (sem credenciais externas).
- `portal_contracts`: envelope de eventos versionado.

## Execução (opção recomendada)

Na raiz `Portal-Escarlate/backend-dart/`:

```bash
docker compose up --build -d
docker compose ps
curl http://localhost:3100/health/live
curl http://localhost:3100/api/auth/health/live
curl http://localhost:3100/api/news/health/live
```

O primeiro comando gera a imagem Dart para cada app. Essa abordagem privilegia
clareza; reduzir tempo de build e uso de memória fica para a etapa seguinte.

## Execução usando SDK Dart

Requer Dart >=3.9 e NATS se for testar o barramento:

```bash
dart pub get
dart analyze
dart test
PORTAL_INTERNAL_TOKEN=local-dev-token-change-me dart run apps/auth_service/bin/main.dart
```

Em outro terminal:

```bash
PORTAL_INTERNAL_TOKEN=local-dev-token-change-me dart run apps/api_gateway/bin/main.dart
```

Se o Gateway roda no host sem Docker, os serviços esperados precisam estar em
`127.0.0.1` e nas portas especificadas em `apps/api_gateway/bin/main.dart`.

## Verificação do barramento (duas sessões)

Inicie NATS com `docker compose up -d nats` e execute:

```bash
dart run packages/portal_events/bin/consume.dart
# Em outro terminal:
dart run packages/portal_events/bin/publish.dart
```

O consumidor exibe o ID do evento. NATS guarda o cursor durável e deduplica
publicações pelo `eventId` dentro de sua janela de deduplicação configurada.

## Mapeamento HTTP

- `GET /health/live` → saúde do Gateway
- `GET /api/auth/health/live` → Auth service
- `GET /api/news/health/live` → News service
- `POST /api/auth/login` → Auth (mesma rota, sem remover prefixos)
- `POST /api/auth/register/request` e `GET /api/auth/verify-email` → Registration
- `POST /api/auth/password/forgot` e `/reset` → Password Recovery
- `/api/email-connections/*` e `/api/google/callback` → Email
- Demais rotas de notícias e IA preservam seu serviço original.

A porta 3100 ainda não substitui a porta 3000: os serviços de negócio Dart
estão em construção. Não alterar `VITE_API_URL` nesta etapa.

## Segurança e limites desta primeira etapa

1. As senhas do Compose são **exclusivamente para desenvolvimento local**.
2. Os serviços só publicam HTTP na rede interna do Compose, exceto o Gateway.
3. `GET /health/live` é público; demais caminhos exigem `x-internal-token`
   e o Gateway injeta esse header com um segredo local.
4. O Gateway encaminha múltiplos `Set-Cookie`, redirects, corpo da resposta
   em stream, CORS com origens permitidas, timeout e limite de 1 MiB por request.
   Sessões, autorização do usuário, limites distribuídos e CSRF completo
   dependem das próximas etapas. **Não expor em produção** ainda.
5. Eventos usam `at least once`: futuramente implementar inbox idempotente,
   outbox transacional e contratos por domínio antes de criar regras de negócio.
6. Se o evento alimentar e-mail ou qualquer outra ação externa, não
   executar a ação sem idempotência e política de retentativas.
7. Cada serviço possui seu banco local, mas o exemplo Docker usa o mesmo
   superusuário para todos. Em produção, separar credenciais e permissões.
8. `dart_nats` possui partes do JetStream marcadas como experimentais:
   validar a integração com testes reais antes da migração de negócio.

## Organização dos arquivos

`packages/` contém contratos e adapters reutilizáveis. `apps/` contém cada
executável de serviço. Novas funcionalidades deverão entrar em `domain/`,
`application/`, `infrastructure/` e `presentation/` **dentro** de cada app.
Não importar regras de negócio de outro microsserviço.

## Pendente de validação neste pacote

Como este ambiente de geração não possui executável Dart nem Docker, não foi
possível executar `dart pub get`, `dart analyze`, `dart test` ou o smoke NATS.
O workflow adicionado executará `dart analyze` e `dart test` no GitHub após
o pacote ser incorporado ao repositório. Execute também `dart format .`
antes do commit para normalizar a formatação.


## Primeira etapa da migração (infraestrutura)

- As rotas usadas pelo React são encaminhadas via HTTP síncrono, sem RPC por NATS.
- Defina APP_URL e ALLOWED_ORIGINS (lista separada por vírgulas) no Gateway.
  Origem fora da allowlist é rejeitada. Requests com cookies de sessão e
  sem Origin/Referer são bloqueadas em métodos mutáveis; para clientes nativos
  haverá autenticação apropriada nas etapas posteriores.
- Em um PostgreSQL de desenvolvimento recém-criado, o Compose executa
  init.sql e depois schema.sql, criando as tabelas de Auth, Email,
  Registration e Recovery, com outbox/inbox iniciais.
- **Volumes existentes não executam scripts de init novamente.** Aplicar
  migrações explicitamente, após backup; não apagar volumes de produção.
- Os tipos de evento portal.* estão declarados, mas publicação transacional
  outbox, idempotência inbox e consumidores de domínio ainda serão
  implementados e validados nas respectivas etapas.
- Testes de integração: dart test test/routing_test.dart
  test/gateway_proxy_test.dart. Testar também dart analyze e dart test.


## 2/6 — Auth Service (ainda pendente de validação)

O serviço Dart passou a conter endpoints compatíveis com o Auth Node:
login, logout, consulta de sessão, existência/criação de usuário e troca
de senha. O banco utilizado é auth_db.users_2.

- Senhas PHC Argon2id compatíveis (19456 KiB, t=2, p=1).
- Cookie portal_session HMAC-SHA256 com expiração de 7 dias.
- Transações PostgreSQL gravam eventos na tabela event_outbox;
  publicador NATS ainda será implementado nas próximas etapas.
- Configure AUTH_SECRET no ambiente; o valor padrão no Compose é
  exclusivamente para desenvolvimento local.
- Teste com dart test test/auth_service_test.dart e execute dart analyze.
- Node, React, Flutter e os serviços excluídos do escopo permanecem intactos.

A implementação não foi validada em um SDK Dart local neste ambiente.
Não exponha o Gateway ou o serviço de Auth Dart em produção até a suíte
Dart, a migração de banco e os testes end-to-end passarem.


## Etapa 3/6 — Email Service (não validada em produção)

Serviço Dart implementado em apps/email_service, com rotas de administração
compatíveis com Node: GET /api/email-connections,
POST /api/email-connections/google/start,
GET /api/email-connections/google/callback (ou /api/google/callback),
PATCH /api/email-connections/:id/priority e DELETE /api/email-connections/:id.

- APP_URL: origem do frontend para onde o OAuth redireciona.
- AUTH_SECRET: mesma chave das sessões Auth Node/Dart.
- SECRETS_ENCRYPTION_KEY: mesma chave de cifragem Node para enc:v1:.
- GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET e GOOGLE_REDIRECT_URI: OAuth Google.
- EMAIL_EVENTS_ENABLED: false até Registration e Recovery implementarem os
  endpoints internos GET /internal/registration/email-requests/:requestId e
  GET /internal/password-recovery/email-requests/:requestId.
- O barramento transporta somente IDs; dados de e-mail e links secretos são
  obtidos por HTTP interno autenticado, nunca gravados no JetStream.
- O consumidor é at-least-once. A deduplicação por event_id protege o estado
  persistido, mas envios externos podem ser repetidos após falhas ambíguas.
- Se o banco já foi inicializado, aplicar migrations/001_email_inbox.sql
  manualmente após backup. Scripts do diretório init só rodam em volume novo.
- Testes: dart test test/email_service_test.dart e
  dart test test/email_events_test.dart, além de dart analyze e dart test.

A configuração padrão do Compose para Google é apenas um placeholder de
laboratório: não permite OAuth real. Configure credenciais de teste na .env.
Não exponha as portas internas dos serviços nem configure segredos padrão
em produção. O backend Node e os quatro serviços fora do escopo não mudam.


## Etapa 4/6 — Registration Service

POST /api/auth/register/request e /api/auth/register validam os campos,
consultam Auth via HTTP e registram uma solicitação pendente no PostgreSQL.
GET /api/auth/verify-email confirma um código único e cria o usuário via
HTTP interno. O controle de concorrência utiliza FOR UPDATE no token.

O pedido contém somente requestId na outbox e no NATS. O Email Service
obtém o link por GET interno autenticado em
/internal/registration/email-requests/:requestId. A senha não sai do banco
Registration, exceto seu hash Argon2id enviado ao Auth no momento da criação.

REGISTRATION_TOKEN_SECRET precisa ser um segredo exclusivo com >=32 chars;
não compartilhar o valor com o frontend nem versionar segredos de produção.
REGISTRATION_EVENTS_ENABLED=false por padrão; habilite junto com
EMAIL_EVENTS_ENABLED somente em integração controlada.

A construção e testes do código passam pelo GitHub Actions. A operação
com credenciais reais Google e PostgreSQL, a publicação/entrega NATS e
a proteção contra abuso em múltiplas réplicas ainda exigem teste de campo.


## 5/6 — Password Recovery Service

- `POST /api/auth/password/forgot` inicia a recuperação com resposta
  indistinguível para e-mails existentes e inexistentes.
- `POST /api/auth/password/reset?code=...` valida senha e código, solicita
  atualização ao Auth por HTTP interno e consome o token após confirmação.
- PostgreSQL em `password_recovery_db.password_recovery_tokens` armazena
  somente hash de código e metadados de expiração/uso único.
- A outbox transacional publica `portal.password_recovery.requested.v1`,
  contendo apenas o requestId, para o consumidor Email JetStream.
- Email obtém o destinatário e o link por HTTP interno autenticado.
- Configure `PASSWORD_RECOVERY_TOKEN_SECRET` (segredo exclusivo >=32 chars),
  `APP_URL`, `AUTH_SERVICE_URL` e `PORTAL_INTERNAL_TOKEN`.
- `PASSWORD_RECOVERY_EVENTS_ENABLED=false` por padrão. Para testar envio,
  configure também `EMAIL_EVENTS_ENABLED=true` e credenciais Gmail de teste.
- Testar: `dart analyze`, `dart test` e
  `dart test test/password_recovery_service_test.dart`.

Esta versão ainda não substitui o Node em produção. Avaliar reentregas
NATS, corrida de tokens, comunicação segura entre serviços, rate limiting
distribuído e falha parcial entre atualização no Auth e consumo local.
