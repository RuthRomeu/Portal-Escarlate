# Testes do cadastro Dart

Execute a partir de backend-dart:

    dart pub get
    dart analyze
    dart test test/registration_service_test.dart
    dart test

Fluxo integrado (quando Auth, Email e NATS estiverem configurados):

1. Solicite cadastro pelo Gateway (porta 3100).
2. Confira a linha da tabela email_verification_tokens.
3. Confira que event_outbox contém requestId e não contém code ou URL.
4. Confira o evento portal.registration.verification_requested.v1 no NATS.
5. Confira GET interno de email request usando o token de serviço.
6. Envie o email pela API Gmail em conta de teste.
7. Confirme o código uma vez e verifique a conta em auth_db.users_2.
8. Refaça a confirmação: deve falhar sem recriar usuário.
9. Repita após 5 minutos: o código deve expirar.
10. Simule falha de HTTP no Auth e verifique o token ainda não consumido.

Não habilite em produção somente com testes unitários. Validar rate limiting
distribuído, anti-abuso, retry/backoff e possíveis reenvios de Gmail.
