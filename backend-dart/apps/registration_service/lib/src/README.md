# Registration Service — etapa 4/6

Rotas públicas compatíveis com Node:
- POST /api/auth/register/request
- POST /api/auth/register
- GET /api/auth/verify-email?code=...

A comunicação síncrona com Auth usa HTTP interno autenticado.
O link de confirmação é calculado via HMAC do requestId, usando
REGISTRATION_TOKEN_SECRET; o banco persiste apenas o hash SHA-256 do código.
Uma requisição guarda o cadastro pendente e um evento de outbox na mesma
transação PostgreSQL. O NATS só recebe requestId, sem código, senha ou URL.
O Email Service busca os dados sensíveis pelo endpoint HTTP:
GET /internal/registration/email-requests/:requestId

Um token só pode ser consumido após o Auth confirmar criação do usuário.
Um lock FOR UPDATE serializa tentativas simultâneas. Caso a atualização
no Auth tenha sucesso e a transação local falhe, a próxima tentativa pode
reconciliar o estado via resposta de conflito + consulta ao Auth.

REGISTRATION_EVENTS_ENABLED=false por padrão. Para habilitar fluxo de e-mail
em laboratório, ligar REGISTRATION_EVENTS_ENABLED e EMAIL_EVENTS_ENABLED.
Para volumes PostgreSQL existentes, não apagar dados de produção.
O controle de IP/e-mail é local em memória, ainda não distribuído.

A outbox usa delivery at-least-once e deduplicação NATS por eventId.
Limites conhecidos: eventos de um link revogado podem alcançar o consumidor
e devem ser classificados como expirados/não entregáveis; testar reenvios,
confirmações simultâneas e falhas entre Auth/PostgreSQL antes de produção.
