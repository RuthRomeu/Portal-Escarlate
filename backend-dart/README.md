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
