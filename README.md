# BPAG-UOL
🛒 Integração de Pagamentos BPAG (API V3)
📌 Visão Geral
Este projeto contempla a atualização e integração do sistema da Procfit com o gateway de pagamentos da BPAG, migrando da arquitetura V1 para a nova V3. O objetivo é processar pagamentos via Cartão de Crédito, Pix e Boleto, gerenciando todo o ciclo de vida transacional diretamente pelo banco de dados (SQL Server) e aplicação legado.

🏗️ Arquitetura Técnica
A camada de integração foi desenvolvida fortemente em T-SQL para centralizar a geração de payloads e regras de criptografia.

Geração de Payload: Utilização nativa do FOR JSON PATH para construção dinâmica dos corpos de requisição HTTP.

Autenticação: Baseada no protocolo UOLWS, utilizando criptografia HMAC-SHA256 e codificação Base64.

Procedures Principais: * sp_GerarAuthorizationUOL: Gera o cabeçalho final de autorização a ser injetado no request.

sp_GerarPayloadPedidoV3: Extrai os dados das tabelas de vendas e formata o JSON do pedido.

🔐 Autenticação e Credenciais (Ambiente Sandbox)
Atualmente, a API exige a assinatura via cabeçalho Authorization.

⚠️ Nota: Está previsto no roadmap da BPAG a atualização para o padrão OAuth 2.0. Quando disponibilizado, o módulo de autenticação deverá ser refatorado.

Dados de Homologação (Sandbox):

Base URL: https://sandbox-psp.bpag.com.br

Merchant ID / Account ID: ultrafarma-hml

Access ID / Public Key: c23ad060dc0aa175d64c8731296486a7

Secret Key (Assinatura): PNMD7f2PjkGXntUXrYhGcOvBJJACsOSKPIdcJTPbHn0=

Cabeçalhos Obrigatórios:

Merchant: Identificação do lojista (ex: ultrafarma-hml)

Account: Conta (ex: ultrafarma-hml)

Date: Data no formato EEE, d MMM yyyy HH:mm:ss z (GMT)

Authorization: UOLWS access-id:signature:hmac-algorithm:protocol-version

🚀 Endpoints Principais
A documentação completa dos contratos (Swagger) define os seguintes fluxos transacionais:

Criar Pedido (Transação): POST /upbc-service-fe/v1/order/purchase

Payload exigido: amount (em centavos), payments (array com dados do cartão/pix), reference (ID interno), requestDate e details (dados do cliente).

Captura Posterior (Cartão): PUT /upbc-service-fe/v1/order/{orderId}/capture

Cancelamento/Estorno: PUT /upbc-service-fe/v1/order/{orderId}/void

Consulta de Pedido: GET /upbc-service-fe/v1/order/{orderId}

🔄 Tratamento de Retornos
O sistema deve interpretar os códigos HTTP da BPAG para validar a comunicação:

200 OK / 201 Created: Sucesso na requisição.

400 Bad Request: Payload inválido ou erro de validação.

401 / 403: Falha na autenticação/assinatura HMAC.

500 Internal Server Error: Erro no gateway.

Avaliação de Pagamento (Nó transactions):
A resposta de sucesso (200 OK) não garante o pagamento aprovado. É obrigatório ler o array transactions dentro da resposta e avaliar o campo status:

✅ Aprovado: Status PRE_AUTHORIZED ou PAID. (Normalized: PROCESSED_AUTHORIZED).

❌ Recusado: Status REJECTED. (Normalized: PROCESSED_REJECT). O motivo do erro virá no campo rawMessage.

🧪 Massa de Dados para Testes (QA)
Os cartões de crédito para o ambiente de Sandbox são fornecidos pela adquirente Getnet.

Regras para simulação:

Aprovação: Utilizar um dos PANs de teste válidos. A data de vencimento (expDate) deve, obrigatoriamente, ser uma data futura válida (ex: 2029-12).

Recusa por Vencimento: Utilizar um PAN válido, mas informar uma data de vencimento expirada/inválida.

Recusa por Cartão Inválido: Utilizar qualquer PAN fora do padrão fornecido (exemplo: 4111111111111111).

Cartões de Teste Principais:

Mastercard: 5447318879391031 | CVV: 528

Visa: 4220612154786956 | CVV: 083

Amex: 376442058032004 | CVV: 1589

Elo: 5067230000009011 | CVV: 568

Hipercard: 6370950924782803 | CVV: 832

🛠️ Manutenção e Tarefas (Roadmap)
[x] Implementação da criptografia HMAC-SHA256 no SQL.

[x] Estruturação da procedure de Autenticação (sp_GerarAuthorizationUOL).

[ ] Desenvolvimento da procedure de Payload (sp_GerarPayloadPedidoV3).

[ ] Rotina de expurgo de Logs (Limpeza de tabelas de requisição com mais de 15 dias).

[ ] Refatoração da Aplicação Principal (Remoção de hardcode legado).

[ ] Configuração de Webhooks para conciliação assíncrona.

[ ] Operação Assistida (Hypercare) pós Go-Live.
