# Migração do backend JavaScript para Dart

Base: main (frontend Flutter 6/6 integrado).
Arquitetura: cliente → Gateway → serviços por HTTP; NATS JetStream
exclusivamente para eventos de domínio entre microsserviços.

## Etapas

- [~] 1/6 Infraestrutura/Gateway — código implementado; validar Dart e Docker localmente
- [~] 2/6 Auth Service — endpoints implementados; testes Dart/Docker pendentes
- [~] 3/6 Email Service — rotas, Google OAuth, Gmail e consumidor NATS implementados; falta validar execução
- [ ] 4/6 Registration Service
- [ ] 5/6 Password Recovery Service
- [ ] 6/6 Testes integrados e compatibilidade

## 1/6 — Alterações desta branch

- Encaminhamento por rota pública sem reescrever URLs usadas pelo React.
- HTTP síncrono: múltiplos Set-Cookie, redirects, CORS com allowlist,
  timeout, limites de request e token interno injetado pelo Gateway.
- PostgreSQL: schema local inicial dos quatro domínios, outbox e inbox.
- Contratos nominais de eventos NATS portal.*. Sem proxy via barramento.
- Testes unitários de roteamento e testes HTTP com upstream simulado.

## 2/6 — Auth Service

- Login, logout, sessão e endpoints HTTP internos de usuários.
- Modelo users_2 em PostgreSQL, hashes PHC Argon2id e sessões HS256.
- Dados de eventos de criação e alteração de senha gravados na outbox
  na mesma transação dos dados de negócio.
- Testes de rotas, cookies, autenticação interna e formatos legados.
- Publicação outbox para NATS ainda pendente; NATS não é proxy HTTP.

## Limites

O backend Node e o frontend não foram alterados. Somente Auth possui lógica de negócio Dart. Email, Registration e Recovery
continuam apenas com health checks. A outbox de Auth ainda não tem worker,
e os serviços Dart ainda não são substitutos de produção.
Não substituir o backend ativo. Não considerar a etapa validada sem:

    cd backend-dart
    dart pub get
    dart format --output=none --set-exit-if-changed .
    dart analyze
    dart test
    docker compose config
    docker compose up --build -d
    curl http://localhost:3100/health/live

Executar testes end-to-end de fluxo real apenas após as etapas de negócio.


Validação adicional: dart test test/auth_service_test.dart; verificar a
configuração AUTH_SECRET, as credenciais PostgreSQL e os logs do Compose.
Execute dart format . antes da verificação final.


## 3/6 — Email Service (implementação proposta)

- Conexões Gmail em email_db.email_connections, com prioridade e CRUD administrativo.
- Refresh tokens AES-256-GCM com prefixo enc:v1:, compatível com Node.
- OAuth 2.0 Google: autorização por admin, state HMAC e callback com redirect.
- Envio Gmail API em MIME texto + HTML, usando OAuth refresh token.
- Consumo NATS JetStream usando requestId (sem tokens/link secreto no evento).
- Consulta HTTP interna dos dados do e-mail e registro inbox/outbox.
- EMAIL_EVENTS_ENABLED=false até Registration e Recovery exporem as rotas de lookup.
- Migração 001_email_inbox.sql requerida para volumes PostgreSQL existentes.
- Testes unitários/mocks adicionados, mas SDK Dart e Docker não foram executados.

### Antes de aprovar 3/6

- dart pub get; dart format .; dart analyze; dart test.
- docker compose config; docker compose up --build -d.
- Validar oauth.callback real e Gmail usando credenciais de teste.
- Validar a criptografia com um token enc:v1: produzido pelo Node.
- Validar idempotência, retentativas e desligamento dos consumidores no NATS.
- Não usar em produção enquanto as etapas dependentes estiverem incompletas.
