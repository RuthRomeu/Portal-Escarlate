# Password Recovery Service em Dart — etapa 5/6

Camadas: domain (tokens, contratos e validações), application (solicitações,
limites e alteração de senha), infrastructure (Postgres, HTTP Auth e
publisher de outbox NATS), presentation (rotas HTTP).

Requisições HTTP permanecem síncronas; JetStream trafega apenas eventos
entre microsserviços. O código de reset é derivado por HMAC de um requestId
aleatório e secreto, e só seu digest SHA-256 é salvo no PostgreSQL.
A mesma solicitação tem evento persistido na outbox, com requestId opaco.

O consumidor Email recupera o link por HTTP interno com token de serviço.
É obrigatório manter PASSWORD_RECOVERY_TOKEN_SECRET secreto e separado de
REGISTRATION_TOKEN_SECRET. Não incluir tokens em logs.
A URL pública usada pelo frontend permanece /reset-password?code=...
Um SELECT FOR UPDATE protege o consumo concorrente do código. Para
serviços em múltiplas instâncias, rate limits devem usar storage comum.

Limites: outbox é at-least-once; integração externa Gmail pode duplicar
envios após respostas ambíguas. Operação de mudança de senha no Auth não
é atômica com a transação no banco Recovery. Não usar em produção ainda.
