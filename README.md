📚 Documentação Técnica - Integração BPAG V3 (Ultrafarma)

📌 Visão Geral do Projeto

Esta documentação descreve o fluxo técnico e os objetos de banco de dados para a integração de pagamentos com o gateway BPAG (UOL / Getnet) na sua nova versão V3.

A arquitetura foi desenhada de forma centralizada no banco de dados (SQL Server / T-SQL). Essa abordagem diminui o acoplamento da aplicação (ERP/Robô) com regras de formatação e criptografia pesada, centralizando a montagem do JSON (via FOR JSON PATH) e a assinatura digital (HMAC-SHA256 / UOLWS).

🔄 Fluxo de Integração e Arquitetura

O ecossistema é baseado na orquestração de Stored Procedures. A aplicação cliente ou o robô não precisa montar o JSON nem calcular hashes de segurança. O fluxo de disparo funciona da seguinte maneira:

O Robô/ERP informa o número da Pré-venda/Pedido.

O banco de dados monta o payload JSON e os cabeçalhos de autenticação.

O banco de dados realiza o disparo HTTP REST para a API BPAG V3.

O retorno é processado automaticamente e o status financeiro é atualizado nas tabelas de fila.

🛠️ Procedures Envolvidas na Integração

Abaixo estão listadas as principais procedures que compõem o motor da integração BPAG V3.

1. sp_ProcessarPedidoBPAG_V3 (A Procedure Principal/Orquestradora)

Esta é a única procedure que o robô/desenvolvedor precisa chamar ativamente para realizar a transação de ponta a ponta.

O que ela faz: Consulta as credenciais na tabela PARAMETROS_BPAG_V3, resgata o payload JSON estruturado, gera o header de autorização, dispara a requisição HTTP (POST) para a BPAG e chama a procedure de retorno para atualizar o status.

Parâmetros de Entrada:

@PREVENDA NUMERIC(15): O identificador único da pré-venda/pedido no ERP.

Retorno: Retorna um result set com o status HTTP da requisição e a mensagem de retorno da adquirente.

2. sp_GerarPayloadPedidoV3 (Uso Interno/Geração de Dados)

O que ela faz: Extrai os dados das tabelas de vendas e monta dinamicamente o corpo da requisição transacional (blocos details, customers, products, payments, etc.) garantindo a formatação correta e eliminando caracteres de escape indevidos.

3. sp_GerarAuthorizationUOL (Uso Interno/Segurança)

O que ela faz: Gera o cabeçalho final de autorização (padrão UOLWS) que será injetado no request. Utiliza criptografia HMAC-SHA256 e conversão em Base64 nativas do banco (fn_HMAC_SHA256, fn_UOLAuthorization, etc).

4. sp_ProcessarRetornoPedidoV3 (Uso Interno/Conciliação)

O que ela faz: Recebe o retorno JSON bruto da adquirente, faz o parse utilizando JSON_VALUE e atualiza o status financeiro da venda (Aprovado, Recusado, etc.) nas tabelas de fila (PREVENDAS_BPAG_PAYORDER, etc.).

🚀 Como Integrar o Robô (Chamada para os Devs)

Para a equipe de desenvolvimento que está construindo o robô de processamento ou a rotina do ERP, a integração é simplificada. Basta injetar o bloco de código abaixo no fluxo da aplicação no momento em que a transação financeira precisar ser autorizada/processada pela BPAG.

💻 Snippet de Chamada do Robô

-- ==============================================================================
-- CHAMA A INTEGRAÇÃO BPAG V3 (AUTORIZAÇÃO / COMPRA)
-- O robô deve passar apenas o número da pré-venda. O banco cuida do resto.
-- ==============================================================================

DECLARE @IdPrevenda NUMERIC(15) = [INSERIR_VARIAVEL_DO_ROBO_AQUI];
DECLARE @Retorno INT;

-- Executa a orquestração completa da transação
EXEC @Retorno = dbo.sp_ProcessarPedidoBPAG_V3 
    @PREVENDA = @IdPrevenda;

-- Opcional: O desenvolvedor pode ler o Result Set retornado pela procedure 
-- para logar o HttpStatus e StatusTransacao na aplicação (ex: PRE_AUTHORIZED, REJECTED).


📋 O que os Desenvolvedores precisam garantir antes de chamar:

Dados Íntegros: A pré-venda já deve estar devidamente gravada nas tabelas de origem (PDV_PREVENDAS, clientes, produtos, etc.) para que a sp_GerarPayloadPedidoV3 consiga montar o JSON sem falhas.

Ambiente Parametrizado: A tabela PARAMETROS_BPAG_V3 deve estar populada com as credenciais corretas do ambiente (Sandbox ou Produção), incluindo URL_BASE, MERCHANT, ACCOUNT, ACCESS_ID e SECRET_KEY.

🚦 Tabela de Status Esperados (Retorno BPAG)

Ao processar a resposta, o ecossistema avalia o nó transactions do JSON devolvido pela BPAG. O desenvolvedor/robô pode esperar os seguintes status principais:

PRE_AUTHORIZED: Transação autorizada com sucesso (Reserva de limite/saldo).

PAID: Transação paga (comum em fluxos de PIX).

REJECTED: Transação recusada. O motivo detalhado estará no campo rawMessage.

Qualquer erro de comunicação HTTP (ex: 400 Bad Request, 403 Forbidden) será tratado e logado pela própria procedure para facilitar o troubleshooting.
