# Arquitetura acordada

Cliente web / Flutter → HTTP Gateway → HTTP síncrono nos serviços.

Comunicação entre serviços por evento → NATS JetStream (assinatura durável).
Não usar request/reply NATS como proxy do frontend.

Cada serviço é dono de seus dados. Persistência pode usar PostgreSQL via
`portal_database`; chamadas externas usam `portal_external_api`. Não acessar
banco de outro serviço. Para consultas compostas, preferir projeções locais
alimentadas por eventos, ou endpoint HTTP específico onde justificável.

Para operações longas, retornar `202 Accepted` + ID de trabalho e disponibilizar
consulta de estado por HTTP quando as funcionalidades forem implementadas.

O tráfego HTTP será síncrono (request/response); os métodos de Dart serão
`async` porque E/S não deve bloquear o runtime.
