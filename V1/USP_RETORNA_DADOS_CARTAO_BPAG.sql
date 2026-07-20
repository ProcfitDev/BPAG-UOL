CREATE PROCEDURE [dbo].[USP_RETORNA_DADOS_CARTAO_BPAG] ( @PREVENDA NUMERIC(15), @LOJA NUMERIC(15), @XML_CARTAO XML ) AS 
BEGIN

	--DECLARE @PREVENDA   NUMERIC(15) = 8001651812
	--       ,@LOJA       NUMERIC(15) = 999
	--       ,@XML_CARTAO XML         = '<captureReturn><status>0</status><msg>Sucesso</msg><bpag_data><status>0</status><msg>PAGO</msg><id>215210708</id><url>https://bpag.uol.com.br/bpag2/control/pagtows?key=dWx0cmFmYXJtYToyMTUyMTA3MDg6ODAwMTY1MTgxMg%3D%3D</url></bpag_data><fi_data><fi><bpag_payment_id>198511345</bpag_payment_id><status>0</status><normalized_status>0</normalized_status><msg>6 - Transacao capturada com sucesso|pan=aD+oy4KlFpYCt1YprfRZf+QavQj2KJUJ8+qvAILyCpY=</msg><payment_method>cielows2p_mastercard</payment_method><normalized_payment_method>mastercard</normalized_payment_method><installments>3</installments><value>21973</value><original_value>21973</original_value><trn_type>3</trn_type><cc_number_hash>gwSzfw2Qa4VDgisCc/ROHcz/b9s=</cc_number_hash><cc_number_masked>548984******4355</cc_number_masked><cc_brand>mastercard</cc_brand><aux_number>793743</aux_number><auth_code>035720</auth_code><id>10020346526HFRIR3C3B</id><date>20170717090605</date><additional_data>Captura de Pre-Autorizacao - Host: CIELO Empresa: 00000000 Terminal: 0001 Codigo Rede: null </additional_data><msg_3ds /><msg_avs /><settlement_msg /><last_attempt><status>0</status><normalized_status>0</normalized_status><msg>6 - Transacao capturada com sucesso|pan=aD+oy4KlFpYCt1YprfRZf+QavQj2KJUJ8+qvAILyCpY=</msg><installments>3</installments><value>21973</value><original_value>21973</original_value><attempt_trn_type>3</attempt_trn_type><cc_number_hash>gwSzfw2Qa4VDgisCc/ROHcz/b9s=</cc_number_hash><cc_number_masked>548984******4355</cc_number_masked><cc_brand>mastercard</cc_brand><aux_number>793743</aux_number><auth_code>035720</auth_code><id>10020346526HFRIR3C3B</id><date>20170717090605</date><additional_data>Captura de Pre-Autorizacao - Host: CIELO Empresa: 00000000 Terminal: 0001 Codigo Rede: null </additional_data><msg_3ds /><msg_avs /></last_attempt></fi></fi_data></captureReturn>'
       
    IF OBJECT_ID('TEMPDB..#DADOS_CARTAO') IS NOT NULL DROP TABLE #DADOS_CARTAO       

	select @PREVENDA                                                                AS PREVENDA
          ,@LOJA                                                                    AS LOJA
          ,2                                                                        AS MEIO_COMUNICACAO
		  ,@XML_CARTAO.value('(//fi/bpag_payment_id)[1]'          , 'numeric(18)' ) as ID_PAGAMENTO
		  ,@XML_CARTAO.value('(//fi/normalized_status)[1]'        , 'numeric(3)'  ) as STATUS_INSTITUICAO_FINANCEIRA
		  ,@XML_CARTAO.value('(//fi/normalized_status)[1]'        , 'numeric(3)'  ) as DESCRICAO_INSTITUICAO_FINANCEIRA
		  ,@XML_CARTAO.value('(//fi/msg)[1]'                      , 'varchar(256)') as MENSAGEM_INSTITUICAO_FINANCEIRA
		  ,@XML_CARTAO.value('(//fi/payment_method)[1]'           , 'varchar(20)' ) as METODO_PAGAMENTO
		  ,@XML_CARTAO.value('(//fi/normalized_payment_method)[1]', 'varchar(20)' ) as METODO_PAGAMENTO_NORMALIZADO
		  ,@XML_CARTAO.value('(//fi/installments)[1]'             , 'varchar(20)' ) as QUANTIDADE_PARCELAS
		  ,@XML_CARTAO.value('(//fi/value)[1]'                    , 'varchar(20)' ) as VALOR_COBRADO
		  ,@XML_CARTAO.value('(//fi/original_value)[1]'           , 'varchar(20)' ) as VALOR_ORIGINAL
		  ,@XML_CARTAO.value('(//fi/trn_type)[1]'                 , 'numeric(2)'  ) as TIPO_TRANSACAO
		  ,@XML_CARTAO.value('(//fi/cc_number_hash)[1]'           , 'varchar(40)' ) as HASH_NUMERO_CARTAO
		  ,@XML_CARTAO.value('(//fi/cc_number_masked)[1]'         , 'varchar(20)' ) as NUMERO_CARTAO
		  ,@XML_CARTAO.value('(//fi/cc_brand)[1]'                 , 'varchar(20)' ) as BANDEIRA
		  ,@XML_CARTAO.value('(//fi/aux_number)[1]'               , 'varchar(30)' ) as NUMERO_NSU
		  ,@XML_CARTAO.value('(//fi/auth_code)[1]'                , 'varchar(30)' ) as CODIGO_AUTORIZACAO
		  ,@XML_CARTAO.value('(//fi/id)[1]'                       , 'varchar(30)' ) as NUMERO_TID
		  ,@XML_CARTAO.value('(//fi/date)[1]'                     , 'varchar(15)' ) as DATA_TRANSACAO
		  ,@XML_CARTAO.value('(//fi/additional_data)[1]'          , 'varchar(256)') as INFORMACOES_ADICIONAIS
		  ,@XML_CARTAO.value('(//fi/settlement_status)[1]'        , 'varchar(2)'  ) as STATUS_CONCILIACAO
		  ,@XML_CARTAO.value('(//fi/settlement_type)[1]'          , 'varchar(2)'  ) as TIPO_CONCILIACAO
		  ,@XML_CARTAO.value('(//fi/settlement_msg)[1]'           , 'varchar(256)') as MENSAGEM_CONCILIACAO
		  ,@XML_CARTAO.value('(//fi/settlement_credit_date)[1]'   , 'varchar(15)' ) as DATA_CREDITO_CONTA_LOJA
      INTO #DADOS_CARTAO
      
	INSERT INTO PDV_PREVENDAS_CARTOES_DETALHES 
			  ( PREVENDA
               ,LOJA
               ,MEIO_COMUNICACAO
			   ,ID_PAGAMENTO
			   ,STATUS_INSTITUICAO_FINANCEIRA    
			   ,DESCRICAO_INSTITUICAO_FINANCEIRA 
			   ,MENSAGEM_INSTITUICAO_FINANCEIRA  
			   ,METODO_PAGAMENTO                 
			   ,METODO_PAGAMENTO_NORMALIZADO     
			   ,QUANTIDADE_PARCELAS              
			   ,VALOR_COBRADO                    
			   ,VALOR_ORIGINAL                   
			   ,TIPO_TRANSACAO                   
			   ,HASH_NUMERO_CARTAO               
			   ,NUMERO_CARTAO                    
			   ,BANDEIRA                         
			   ,NUMERO_NSU                       
			   ,CODIGO_AUTORIZACAO               
			   ,NUMERO_TID                       
			   ,DATA_TRANSACAO                   
			   ,INFORMACOES_ADICIONAIS           
			   ,STATUS_CONCILIACAO               
			   ,TIPO_CONCILIACAO                 
			   ,MENSAGEM_CONCILIACAO             
			   ,DATA_CREDITO_CONTA_LOJA          
			  )

	select PREVENDA                                                                 
          ,LOJA                                                                     
          ,MEIO_COMUNICACAO                                                         
		  ,ID_PAGAMENTO
		  ,STATUS_INSTITUICAO_FINANCEIRA
		  ,DESCRICAO_INSTITUICAO_FINANCEIRA
		  ,MENSAGEM_INSTITUICAO_FINANCEIRA
		  ,METODO_PAGAMENTO
		  ,METODO_PAGAMENTO_NORMALIZADO
		  ,QUANTIDADE_PARCELAS
		  ,CASE WHEN ISNUMERIC(VALOR_COBRADO) = 1 THEN SUBSTRING(VALOR_COBRADO ,1,LEN(VALOR_COBRADO )-2) + '.' + RIGHT(VALOR_COBRADO ,2)
		        ELSE '0'
		   END                              AS VALOR_COBRADO
		  ,CASE WHEN ISNUMERIC(VALOR_ORIGINAL)= 1 THEN SUBSTRING(VALOR_ORIGINAL,1,LEN(VALOR_ORIGINAL)-2) + '.' + RIGHT(VALOR_ORIGINAL,2)
		        ELSE '0'
		   END                              AS VALOR_ORIGINAL
		  ,TIPO_TRANSACAO
		  ,HASH_NUMERO_CARTAO
		  ,NUMERO_CARTAO
		  ,BANDEIRA
		  ,NUMERO_NSU
		  ,CODIGO_AUTORIZACAO
		  ,NUMERO_TID
		  ,SUBSTRING(DATA_TRANSACAO,1,4)+'-'+
		   SUBSTRING(DATA_TRANSACAO,5,2)+'-'+
		   SUBSTRING(DATA_TRANSACAO,7,2)+'T'+
		   SUBSTRING(DATA_TRANSACAO,9,2)+':'+
		   SUBSTRING(DATA_TRANSACAO,11,2)+':'+
		   SUBSTRING(DATA_TRANSACAO,13,2) AS DATA_TRANSACAO
		  ,INFORMACOES_ADICIONAIS
		  ,STATUS_CONCILIACAO
		  ,TIPO_CONCILIACAO
		  ,MENSAGEM_CONCILIACAO
		  ,SUBSTRING(DATA_CREDITO_CONTA_LOJA,1,4)+'-'+
		   SUBSTRING(DATA_CREDITO_CONTA_LOJA,5,2)+'-'+
		   SUBSTRING(DATA_CREDITO_CONTA_LOJA,7,2) AS DATA_CREDITO_CONTA_LOJA
      FROM #DADOS_CARTAO
      
END 

GO