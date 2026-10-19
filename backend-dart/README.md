# Portal Escarlate — Backend Dart (fundação)

Base técnica **aditiva**. O backend Node.js (`../backend`) e o React (`../frontend`)
continuam inalterados. Nenhum endpoint de negócio foi migrado.

## Componentes

- Gateway HTTP síncrono: porta **3100**. Os caminhos `/api/{serviço}/...` são
  encaminhados diretamente via HTTP; o event bus NÃO é usado como proxy.
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
- Mesma regra para `registration`, `ai`, `email`, `news-summary`,
  `article-summary`, `password-recovery`.

A raiz `/api/...` aqui é **nova**: o frontend React ainda aponta ao backend antigo.
Não altere `VITE_API_URL` nesta etapa.

## Segurança e limites desta primeira etapa

1. As senhas do Compose são **exclusivamente para desenvolvimento local**.
2. Os serviços só publicam HTTP na rede interna do Compose, exceto o Gateway.
3. `GET /health/live` é público; demais caminhos exigem `x-internal-token`
   e o Gateway injeta esse header com um segredo local.
4. O Gateway inicial não implementa autenticação de usuário, cookies
   múltiplos, CORS cross-origin, streaming ou rate limiting. Não expô-lo
   em produção até completar essas etapas.
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
