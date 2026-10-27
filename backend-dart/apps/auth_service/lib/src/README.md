# Auth Service Dart — migração 2/6

Camadas:

- domain/: entidade AuthUser, validações, Argon2id e sessões HMAC-SHA256.
- infrastructure/: repositório PostgreSQL das tabelas users_2 e event_outbox.
- presentation/: rotas HTTP externas/internas e rate limit básico.
- bin/: composição das dependências e inicialização.

Rotas compatíveis com Node:
POST /api/auth/login
POST /api/auth/logout
GET /api/auth/me
GET /internal/auth/users/exists?email=...
POST /internal/auth/users
POST /internal/auth/users/password

Todas as rotas, exceto /health/live, requerem x-internal-token.
Rotas /internal não são publicadas pelo Gateway.

Eventos auth.user_created e auth.password_updated são gravados na outbox
com as mutações, sem segredos. O publisher outbox -> NATS ainda será
implementado em outra etapa. O NATS NÃO é proxy para o HTTP.

O hash PHC Argon2id (19456 KiB, t=2, p=1) e o cookie portal_session
(HMAC-SHA256, 7 dias) preservam compatibilidade com o código Node.
Executar os testes de hashes com fixtures reais antes de produção.

Limitadores de login neste checkpoint são locais ao processo e por
e-mail (5 tentativas em 10 minutos); para múltiplas réplicas, mover o
contador a um storage compartilhado confiável.

Não usar esta etapa em produção antes da suíte Dart, do banco de testes,
da revisão do proxy e dos fluxos integrados serem validados.
