# Contratos HTTP básicos

`GET /health/live` em cada processo → `200` com `{status, service}`.
Gateway `GET /api/<serviço>/health/live` → encaminhamento HTTP direto.
O Gateway responde `404` a serviços desconhecidos e `502` quando um serviço
conhecido não está acessível. Nenhum endpoint de autenticação/notícia foi
migrado nesta etapa.

Serviços aceitam `x-internal-token` para endpoints não públicos. O Gateway
substitui qualquer header do cliente com o token configurado no servidor.
Em produção, complementar com isolamento de rede e autenticação forte (mTLS).
