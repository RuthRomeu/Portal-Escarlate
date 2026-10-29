# Email Service Dart — etapa 3/6

- domain/: conexões e interfaces de persistência.
- infrastructure/: PostgreSQL, AES-GCM enc:v1: e OAuth Google.
- application/: envio MIME/Gmail e consumidor JetStream.
- presentation/: HTTP administrativo com sessão admin.

O gateway transmite requests por HTTP. O NATS somente distribui eventos.
O consumidor exige requestId e resolve dados sensíveis por HTTP autenticado
nos serviços de registro/recuperação. Essa parte está desabilitada até a
implementação dos endpoints nas etapas 4 e 5.

O consumidor não garante exactly-once de ações externas. Para produção,
realizar testes de falhas ambíguas da Gmail API e definir reconciliação.
