# Camadas do serviço

Apenas o `bin/main.dart` e o endpoint `/health/live` existem nesta etapa.

Ao adicionar regras de negócio, organizar dentro deste `lib/src/`:

- `domain/`: entidades e contratos puros do domínio.
- `application/`: casos de uso e orquestração.
- `presentation/http/`: controladores e validação HTTP.
- `infrastructure/database/`: repositórios PostgreSQL de propriedade deste serviço.
- `infrastructure/external/`: adaptadores de APIs externas.
- `infrastructure/events/`: eventos emitidos e consumidos.

Não importar regras de negócio de outro microsserviço.
