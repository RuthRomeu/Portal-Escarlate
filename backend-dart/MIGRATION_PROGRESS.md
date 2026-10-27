# Migração do backend JavaScript para Dart

Base: main (frontend Flutter 6/6 integrado).
Arquitetura: cliente → Gateway → serviços por HTTP; NATS JetStream
exclusivamente para eventos de domínio entre microsserviços.

## Etapas

- [~] 1/6 Infraestrutura/Gateway — código implementado; validar Dart e Docker localmente
- [ ] 2/6 Auth Service
- [ ] 3/6 Email Service
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

## Limites

O backend Node e o frontend não foram alterados. Os serviços Dart de negócio
continuam apenas com health checks. Outbox/inbox ainda são tabelas sem workers
e sem consumidores; não há migração de autenticação, e-mail ou tokens reais.
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
