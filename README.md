# 📚 Documentação Técnica - Integração BPAG V3 (Ultrafarma)

## 📌 Visão Geral do Projeto
Este projeto contempla a atualização e integração do sistema da Procfit com o gateway de pagamentos da **BPAG (UOL / Getnet)**, migrando da arquitetura legada (V1 - XML) para a nova **V3 (API REST / JSON)**. 

O objetivo é processar pagamentos via Cartão de Crédito, Pix e Boleto, gerenciando o ciclo de vida transacional centralizado no banco de dados (SQL Server / T-SQL). Essa abordagem diminui o acoplamento do ERP, abstraindo a montagem estrutural do JSON e o processamento de criptografia.

---

## 🏗️ Arquitetura e Segurança (UOLWS)
* **Geração de Payload:** Utilização nativa do `FOR JSON PATH` e `JSON_QUERY` para construção dinâmica dos corpos de requisição HTTP, eliminando caracteres de escape indevidos.
* **Autenticação:** Baseada no protocolo **UOLWS**, utilizando assinatura digital com criptografia **HMAC-SHA256** e codificação **Base64**.
* **Cabeçalhos Obrigatórios (Headers):**
  * `Content-Type`: application/json
  * `Merchant`: Identificação do lojista (ex: *ultrafarma-hml*)
  * `Account`: Conta (ex: *ultrafarma-pet-hml*)
  * `Date`: Data atualizada dinamicamente no formato GMT (ex: *EEE, d MMM yyyy HH:mm:ss z*)
  * `Authorization`: Assinatura UOLWS (*UOLWS access-id:signature:hmac-algorithm:protocol-version*)
  * `OnBehalfOfAccessId`: Access ID do lojista

*(Nota arquitetural: A API valida a data da requisição para prevenir Replay Attacks. É aplicada uma compensação temporal/sincronia de GMT no banco).*

---

## 🛠️ Objetos de Banco de Dados Envolvidos

### Stored Procedures Principais
1. **`sp_ProcessarPedidoBPAG_V3`** (Orquestradora): Procedure principal de teste e disparo. Busca o payload na fila, injeta os headers, faz o *request* (POST via WinHttp) e chama a rotina de retorno.
2. **`sp_GerarPayloadPedidoV3`**: Extrai os dados das tabelas de vendas (`PDV_PREVENDAS`, clientes, produtos, etc.) e formata o JSON do pedido (blocos `details`, `customers`, `products`, `payments`).
3. **`sp_GerarAuthorizationUOL`**: Gera o cabeçalho final de autorização a ser injetado no request.
4. **`sp_ProcessarRetornoPedidoV3`**: Recebe a resposta JSON da adquirente, faz o parse (via `JSON_VALUE`) e atualiza as tabelas de status financeiro (`PREVENDAS_BPAG_PAYORDER`, etc.).

### Funções Escalares (Criptografia)
* **`fn_UOLAuthorization`**: Compõe a *String-To-Sign* (Método HTTP + MD5 + Headers Canônicos + Data) e calcula a assinatura.
* **`fn_HMAC_SHA256`**: Algoritmo de hash no banco de dados.
* **`fn_Base64ToVarbinary`** / **`fn_VarbinaryToBase64`**: Conversão de encoding necessária para o hash UOLWS.

---

## 🚀 Endpoints Principais (REST)
A comunicação ocorre com os seguintes serviços:

* **Criar Pedido / Autorização:** `POST /upbc-service-fe/v1/order/purchase`
  *(Payload exigido: amount em centavos, payments, reference, requestDate e details)*
* **Captura Posterior (Cartão):** `PUT /upbc-service-fe/v1/order/{orderId}/capture`
* **Cancelamento / Estorno / Void:** `PUT /upbc-service-fe/v1/order/{orderId}/void`
* **Consulta de Pedido:** `GET /upbc-service-fe/v1/order/{orderId}`

---

## 💻 Como Integrar o Robô / ERP (Para Desenvolvedores)

A equipe de desenvolvimento não precisa gerar o JSON nem assinar a requisição. O fluxo é totalmente abstraído. **Basta injetar o comando abaixo** para iniciar o processamento transacional:

```sql
-- ==============================================================================
-- CHAMA A INTEGRAÇÃO BPAG V3 (AUTORIZAÇÃO / COMPRA)
-- O desenvolvedor/robô deve passar apenas o número da pré-venda.
-- ==============================================================================

DECLARE @IdPrevenda NUMERIC(15) = [VARIAVEL_PREVENDA_ERP];
DECLARE @Retorno INT;

-- Executa a orquestração completa da transação
EXEC @Retorno = dbo.sp_ProcessarPedidoBPAG_V3 
    @PREVENDA = @IdPrevenda;

-- A procedure retornará um Result Set contendo:
-- PREVENDA, HttpStatus (ex: 200, 201, 400, 403), StatusTransacao (ex: PRE_AUTHORIZED) e Mensagem.
```

### 📋 Pré-requisitos de Chamada:
1. **Dados Íntegros:** O pedido/pré-venda já deve estar gravado nas tabelas do ERP com clientes e itens vinculados.
2. **Ambiente Parametrizado:** A tabela `PARAMETROS_BPAG_V3` deve estar populada (Credenciais, URL).

---

## 🔐 Credenciais de Homologação (Sandbox)
Se houver a necessidade de testes manuais (ex: via Postman), utilizar a massa abaixo:

* **Base URL:** `https://sandbox-psp.bpag.com.br`
* **Merchant:** `ultrafarma-hml`
* **Account:** `ultrafarma-pet-hml`
* **Access ID:** `c23ad060dc0aa175d64c8731296486a7`
* **Secret Key:** `PNMD7f2PjkGXntUXrYhGcOvBJJACsOSKPIdcJTPbHn0=`

---

## 🚦 Tratamento de Retornos
O sistema interpreta o array `transactions` da resposta. Os principais status são:
* `PRE_AUTHORIZED`: Transação autorizada com sucesso (Reserva de limite/saldo).
* `PAID`: Transação paga (comum em fluxos de PIX).
* `REJECTED`: Transação recusada. O motivo detalhado estará no campo `rawMessage`.
