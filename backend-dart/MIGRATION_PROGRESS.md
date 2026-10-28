# Migração do backend Node.js para Dart

Base: main do repositório Luigi-copia-essa-merda.
Escopo: API Gateway e quatro serviços (Auth, Email, Registration, Recovery).
Arquitetura: HTTP síncrono; NATS JetStream somente entre microsserviços,
transportando eventos de negócio sem tokens, senhas ou links de acesso.

## Checkpoints cumulativos

- [x] 1/6 — Infraestrutura, Gateway e contratos HTTP/eventos
- [x] 2/6 — Auth: users_2, Argon2id, sessões, operações internas
- [x] 3/6 — Email: OAuth, Gmail, conexões, consumidores JetStream
- [x] 4/6 — Registration: pedido, confirmação, token, outbox
- [x] 5/6 — Recovery: solicitação, redefinição, token, outbox
- [~] 6/6 — Integração: testes reais em CI, híbrido Node/Dart, segurança

Os cinco primeiros checkpoints passaram nos testes Dart do GitHub Actions,
mas não foram aprovados para produção. Os testes da etapa 6 ainda precisam
confirmar o fluxo com infraestrutura real.

## Etapa 6

- Teste de ponta a ponta: gateway -> registro -> outbox -> NATS -> e-mail
  simulado (consulta interna) -> confirmação -> Auth -> sessão.
- Teste de recuperação: recuperação -> outbox -> NATS -> e-mail simulado
  -> atualização Auth -> consumo único do token -> login com nova senha.
- Integração em ambiente GitHub Actions isolado com PostgreSQL e NATS reais.
- Nunca registrar URLs de confirmação/reset inteiras nos logs de acesso.
- LEGACY_BACKEND_URL obrigatório quando for necessário acessar as quatro
  funcionalidades excluídas da migração.
- Nunca publicar o código/link secreto no JetStream; usar requestId opaco.

## Pendências antes de produção

1. Teste Google OAuth e Gmail com credenciais de laboratório.
2. Migrações para volumes existentes (com backup), compatibilidade real
   com hashes e sessões Node; testes de cookies no navegador/Flutter.
3. Rate limiting compartilhado para múltiplas instâncias.
4. Política de backoff, inbox/outbox e tratamento de ações externas
   quando a resposta do Gmail é ambígua (não há exactly-once externo).
5. Hardening de secrets, redes, bancos, workers e logging/redaction;
   revisão de event bus, recuperação após restart e resiliência.
6. Teste da convivência híbrida com endpoint Node real.
7. Tornar a mudança de senha idempotente entre bancos independentes.
8. Validar ambiente Docker local e observabilidade/monitoramento.

O backend JavaScript, o frontend e a main permanecem intocados.
