CREATE PROCEDURE [dbo].[USP_BPAG_CAPTURE_TOTAL_RETORNO] (      
                @PREVENDA_BPAG NUMERIC,       
                @PREVENDA      NUMERIC,       
    @XML           VARCHAR(MAX),       
    @XML_ORIGEM    VARCHAR(MAX),       
    @RETORNO       INT OUTPUT      
)      
AS      
      
DECLARE @ESTADO         NUMERIC(15)      
DECLARE @AUX            XML      
      
      
DECLARE @STATUS_CAPTURA_OK         NUMERIC(5)       
DECLARE @STATUS_CAPTURA_ERRO       NUMERIC(5)       
DECLARE @STATUS_FALHA_CONEXAO      NUMERIC(5)       
DECLARE @STATUS_ERRO_PROCESSAMENTO NUMERIC(5)       
      
--------------------------------------------------------------------------------------------      
-- ARMAZENA EM VARIAVEIS TODOS OS POSSIVEIS SATUS QUE PODEM OCORRER AO LONGO DA PROCEDURE --      
--------------------------------------------------------------------------------------------      
SELECT @STATUS_CAPTURA_OK         = STATUS_CAPTURA,           -- FOI CAPTURA E TEVE RETORNO APROVACAO DA TRANSACAO      
       @STATUS_CAPTURA_ERRO       = STATUS_REPROVADO,         -- FOI CAPTURA E TEVE RETORNO REPROVACAO DA TRANSACAO      
       @STATUS_FALHA_CONEXAO      = STATUS_FALHA_CONEXAO,     -- CHECKOUT NAO OBTEVE RETORNO DA BPAG      
       @STATUS_ERRO_PROCESSAMENTO = STATUS_ERRO_PROCESSAMENTO -- FOI CAPTURADO E BPAG RETORNOU ERRO DE PROCESSAMENTO (GERALMENTE INSTABILIDADE NA BPAG E/OU REDECARD)      
  FROM PARAMETROS_BPAG A WITH(NOLOCK)      
        
      
---------------------------------------------------------------------------      
-- FALHA DE COMUNICAXAO NA CHAMADO DO WEBSERVICE. DENTRO DO CHECKOUT.EXE --      
-- NESTE CASO NÃO TEVE NENHUM RETORNO DO BPAG                            --      
-- É GERADO UM XML COM MODELO PADRAO BPAG APENAS PARA NAO TER ALTERACAO  --      
-- NO DECORRER DAS REGRAS DENTRO DA PROCEDURE                            --      
---------------------------------------------------------------------------      
IF substring(@XML,1, 7)  = 'INTERNO'       
BEGIN      
     SET @XML = '<captureReturn>'             +      
                       '<status>-99</status>'     +      
                       '<msg>' + substring(@XML,9, LEN(@xml)) + '</msg>' +      
                '</captureReturn>'          
END      
      
SET @XML = REPLACE(@XML, '<?xml version="1.0" encoding="UTF-8"?>', '')      
SET @AUX = CONVERT(XML, @XML)      
      
------------------------------------------------------------      
-- IDENTIFICA PARA QUAL STATUS O PEDIDO DEVE SER ALTERADO --      
------------------------------------------------------------      
IF @AUX.value('(/captureReturn/bpag_data/status)[1]', 'int') IS NULL OR @AUX.value('(//fi/normalized_status)[1]', 'numeric(3)') IS NULL
   SET @ESTADO = @STATUS_FALHA_CONEXAO      
ELSE      
   SET @ESTADO = CASE WHEN ABS(@AUX.value('(captureReturn/bpag_data/status)[1]', 'int')) =  0 AND @AUX.value('(//fi/normalized_status)[1]', 'numeric(3)') = 0
                      THEN @STATUS_CAPTURA_OK      
                      ELSE CASE WHEN ABS(@AUX.value('(captureReturn/status)[1]', 'int')) = 74       
                                THEN @STATUS_ERRO_PROCESSAMENTO      
                                ELSE @STATUS_CAPTURA_ERRO      
                           END      
                 END         
      
IF ISNULL(@AUX.value('(/captureReturn/bpag_data/status)[1]', 'int'), -1) = 0 AND ISNULL(@AUX.value('(//fi/normalized_status)[1]', 'numeric(3)'), -1) = 0      
   SET @RETORNO = 0      
ELSE       
   --SET @RETORNO = @AUX.value('(captureReturn/status)[1]', 'int')        
     BEGIN      
          --IF ( ISNULL(@AUX.value('(captureReturn/status)[1]', 'int'), -1) = -193 )       
          IF ( ISNULL(@AUX.value('(captureReturn/status)[1]', 'int'), -1) = -193 ) AND ( @AUX.value('(/captureReturn/bpag_data/status)[1]', 'int')  <> 3 )    
          BEGIN      
               IF @AUX.value('(captureReturn/fi_data/fi/last_attempt/status)[1]', 'int') = 0    AND ISNULL(@AUX.value('(//fi/normalized_status)[1]', 'numeric(3)'), -1) = 0    
               SET @RETORNO = 0        
          ELSE       
               SET @RETORNO = ISNULL(@AUX.value('(//fi/normalized_status)[1]', 'numeric(3)'), -1)--ISNULL(@AUX.value('(captureReturn/status)[1]', 'int'),-1)         
          END      
     ELSE      
            SET @RETORNO = ISNULL(@AUX.value('(//fi/normalized_status)[1]', 'numeric(3)'), -1)--ISNULL(@AUX.value('(captureReturn/status)[1]', 'int'),-1)    
     END      
 
 
----------------------------------------------------------------------------------------------
-- ALIMENTA A TABELA DE ENFILEIRAMENTO DE VENDAS QUE SERÃO ENVIADAS POSTERIORMENTE A EQUALS --
----------------------------------------------------------------------------------------------
BEGIN TRY
IF @RETORNO = 0 
BEGIN
	DECLARE @TAB_MASTER_ORIGEM NUMERIC(15)  = (SELECT NUMID FROM TABELAS WHERE TABELA = 'PDV_PREVENDAS');
	DECLARE @DATA_XML	       VARCHAR(255) = @AUX.value('(captureReturn/fi_data/fi/last_attempt/date)[1]', 'varchar(255)')
	DECLARE @DATA_AUTORIZACAO  DATETIME		= NULL;
    DECLARE @CONCILIADORES_PARAMETROS_TAB_MASTER_ORIGEM NUMERIC(15) = (SELECT NUMID FROM TABELAS WHERE TABELA = 'CONCILIADORES')
    DECLARE @CONCILIADORES_PARAMETROS_REG_MASTER_ORIGEM NUMERIC(15) = 3  -- EQUALS
    DECLARE @INICIO_CONCILIACAO DATE    

    SET @INICIO_CONCILIACAO = (SELECT DATA_CORTE FROM CONCILIADORES WITH(NOLOCK)
                                                WHERE TAB_MASTER_ORIGEM = @CONCILIADORES_PARAMETROS_TAB_MASTER_ORIGEM
                                                  AND REG_MASTER_ORIGEM = @CONCILIADORES_PARAMETROS_REG_MASTER_ORIGEM
                                                  AND ATIVO = 'S'
                                                  )  

	IF LEN(@DATA_XML) >= 14
	BEGIN
		SET @DATA_AUTORIZACAO = (
				(
					ISNULL(CONVERT( VARCHAR(2),SUBSTRING(@DATA_XML, 7, 2)),'')
					+ '/'
					+ ISNULL(CONVERT( VARCHAR(2),SUBSTRING(@DATA_XML, 5, 2)),'')
					+ '/'
					+ ISNULL(CONVERT( VARCHAR(4),SUBSTRING(@DATA_XML, 1, 4)),'')
					+ ' '
					+ ISNULL(CONVERT( VARCHAR(2),SUBSTRING(@DATA_XML, 9, 2)),'')
					+ ':'
					+ ISNULL(CONVERT( VARCHAR(2),SUBSTRING(@DATA_XML, 11, 2)),'')
					+ ':'
					+ ISNULL(CONVERT( VARCHAR(2),SUBSTRING(@DATA_XML, 13, 2)),'')
					+ ':000'
				)
		)
	END

    IF @DATA_AUTORIZACAO >= @INICIO_CONCILIACAO 
    BEGIN
	    INSERT INTO CONCILIACOES_TERCEIROS_ENFILEIRAMENTOS_VENDAS ( 
              TAB_MASTER_ORIGEM 
            , REG_MASTER_ORIGEM
            , REG_LOG_INCLUSAO           
            , LOJA          
            , CAIXA          
            , VENDA          
            , MOVIMENTO          
            , TIPO  
            , STATUS -- status padrão da venda = 0, se colocar 1 a venda é enviada como cancelada e não concilia 
            , FINALIZADORA
            , RECARGA
            , SERVICO
            , PDV_ROMANEIO_RECEBIMENTO_CARTAO
            , ROMANEIO_RECEBIMENTO_CARTAO
            , PREVENDA 
            , NSU
            , NSU_HOST
            , AUTORIZACAO
            , DATA_AUTORIZACAO
            , TID
            , PARCELAS
            , VALOR
            , ADQUIRENTE
            , CODIGO_BANDEIRA
            , PRODUTO
            , REDE
            , CODIGO_ESTABELECIMENTO
            , MODO_CAPTURA
		    , AREA_CLIENTE -- CHAVE: LOJA, CAIXA, MOVIMENTO, ORIGEM DA VENDA, TIPO, TAB_MASTER_ORIGEM 
		    , STATUS_XML   
            --, POS_MANUTENCAO_DETALHE
            --, ALTERACAO_VALOR_MOVIMENTO
            , ID_CONCILIADOR
            , STATUS_ARQUIVO
		    --, DESCRICAO_BANDEIRA_BPAG
			, BPAG_ADQUIRENTE_PAGAMENTO
			, BPAG_BANDEIRA_PAGAMENTO
			, BPAG_BANDEIRA_CARTAO
            )            
      
	    SELECT 
		      @TAB_MASTER_ORIGEM				AS TAB_MASTER_ORIGEM 
		    , @PREVENDA_BPAG					AS REG_MASTER_ORIGEM
		    , @PREVENDA							AS REG_LOG_INCLUSAO  
		    , NULL								AS LOJA   
		    , 1									AS CAIXA          
		    , NULL								AS VENDA          
		    , CONVERT(DATE,@DATA_AUTORIZACAO)	AS MOVIMENTO     
		    , 11								AS TIPO  
		    , 0									AS STATUS  -- status padrão da venda = 0, se colocar 1 a venda é enviada como cancelada e não concilia       
		    , NULL								AS FINALIZADORA
		    , NULL								AS RECARGA
		    , NULL								AS SERVICO
		    , NULL								AS PDV_ROMANEIO_RECEBIMENTO_CARTAO
		    , NULL								AS ROMANEIO_RECEBIMENTO_CARTAO
		    , @PREVENDA_BPAG					AS PREVENDA
		    , @AUX.value('(captureReturn/fi_data/fi/last_attempt/aux_number)[1]', 'varchar(255)')	AS NSU
		    , NULL								AS NSU_HOST
		    , @AUX.value('(captureReturn/fi_data/fi/last_attempt/auth_code)[1]', 'varchar(255)')	AS AUTORIZACAO
		    , @DATA_AUTORIZACAO					AS DATA_AUTORIZACAO 
		    , @AUX.value('(captureReturn/fi_data/fi/last_attempt/id)[1]', 'varchar(255)')           AS TID 
		    , NULL								AS PARCELAS
		    , NULL								AS VALOR 
		    , NULL								AS ADQUIRENTE 
		    , NULL								AS CODIGO_BANDEIRA 
		    , NULL								AS PRODUTO
		    , NULL								AS REDE 
		    , NULL								AS CODIGO_ESTABELECIMENTO --CNPJ que será inserido na rotina XML
		    , 11								AS MODO_CAPTURA
		    , NULL								AS AREA_CLIENTE -- CHAVE: LOJA, CAIXA, MOVIMENTO, ORIGEM DA VENDA, TAB_MASTER_ORIGEM
		    , NULL								AS STATUS_XML   -- 1 = PENDENTE, 2 = ENVIADO, 3 = REENVIAR     
		    --, NULL							AS POS_MANUTENCAO_DETALHE
		    --, NULL							AS ALTERACAO_VALOR_MOVIMENTO  
		    --, NULL                          AS TROCA_FINALIZADORA
		    , @CONCILIADORES_PARAMETROS_REG_MASTER_ORIGEM                                           AS ID_CONCILIADOR
		    , 1									AS STATUS_ARQUIVO
		    --, @AUX.value('(captureReturn/fi_data/fi/payment_method)[1]', 'varchar(255)')			AS DESCRICAO_BANDEIRA_BPAG
			, @AUX.value('(captureReturn/fi_data/fi/payment_method)[1]', 'varchar(255)')			AS BPAG_ADQUIRENTE_PAGAMENTO
			, @AUX.value('(captureReturn/fi_data/fi/normalized_payment_method)[1]', 'varchar(255)')	AS BPAG_BANDEIRA_PAGAMENTO
			, @AUX.value('(captureReturn/fi_data/fi/cc_brand)[1]', 'varchar(255)')					AS BPAG_BANDEIRA_CARTAO
    END
END    

END TRY
BEGIN CATCH

	INSERT INTO EQUALS_CAPTURA_VENDAS_BPAG_LOG
	(
		PREVENDA						
		, PREVENDA_BPAG					
		, ORIGEM_TOTAL_OU_PARCIAL	
	)
	SELECT
		@PREVENDA_BPAG
		, @PREVENDA
		, 'T'

END CATCH
      
-----------------------------------------------------------      
-- ALIMENTA TABELA DE CONTROLE DAS TRANSACOES DE CAPTURA --      
-----------------------------------------------------------      
INSERT INTO PREVENDAS_BPAG_CAPTURE  (      
       PREVENDA_BPAG,      
       PREVENDA,      
    XML_ORIGEM,      
       XML_RETORNO,      
    DATA_HORA,      
    STATUS_WS )      
values (@PREVENDA,      
        @PREVENDA_BPAG,      
        @XML_ORIGEM,      
  @AUX,      
  GETDATE(),      
  @RETORNO )      
      
------------------------------------------------------------      
-- GERA LOG DE ACORDO COM STATUS ENCONTRADO ANTERIORMENTE --      
------------------------------------------------------------      
      
INSERT INTO TELEVENDAS_ESTADO_COMANDAS_LOG (      
       REG_MASTER_ORIGEM,      
       ESTADO,      
       DATA_HORA,      
       PREVENDA,      
       PROCESSO,      
       RESPONSAVEL,      
       OBSERVACAO )      
SELECT @PREVENDA,      
       @ESTADO,      
       GETDATE(),      
       @PREVENDA,      
       'CONFIRMACAO',      
 'BPAG',      
       'USP_BPAG_CAPTURE_RETORNO' 
GO