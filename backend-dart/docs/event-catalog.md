# Catálogo de eventos — convenções

Sujeitos permitidos: `portal.<domínio>.<evento>`.
Envelope: eventId, type, schemaVersion, source, occurredAt, correlationId,
payload. Não colocar senhas/tokens/dados pessoais desnecessários no payload.

Por enquanto apenas `portal.demo.ping` existe como ferramenta manual de smoke.
Eventos de domínio (cadastro, notícias, resumos) não são implementados ainda.

**Consumo seguro futuro:** persistir `eventId` por consumidor para deduplicação;
confirmar só depois da transação local; planejar DLQ, retries e outbox.
