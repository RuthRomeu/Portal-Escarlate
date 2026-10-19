# NATS JetStream

O Docker Compose inicia um servidor NATS com JetStream e um volume persistente.
O pacote `portal_events` cria/atualiza o stream `PORTAL_EVENTS`, sujeito `portal.>`,
na primeira conexão. Consumidores `durableName` recebem eventos pendentes após reinício.
Não publicar segredos nem dados pessoais completos em eventos.
