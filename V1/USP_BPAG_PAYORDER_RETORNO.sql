CREATE PROCEDURE [dbo].[USP_BPAG_PAYORDER_RETORNO](@ID NUMERIC, @PREVENDA NUMERIC, @XML VARCHAR(MAX))        
AS        
  
/*  
DECLARE @ID       NUMERIC      = 11744140  
      , @PREVENDA NUMERIC      = 7203987462  
      , @XML      VARCHAR(MAX) = '<payOrderReturn><status>0</status><msg>Sucesso</msg><bpag_data><status>2</status><msg>INVALIDO</msg><id>217860305</id><url>https://bpag.uol.com.br/bpag2/control/pagtows?key=dWx0cmFmYXJtYToyMTc4NjAzMDU6NzIwMzk4NzQ2Mg%3D%3D
</url></bpag_data><fi_data><fi><bpag_payment_id>201207680</bpag_payment_id><status>-105</status><normalized_status>-105</normalized_status><msg>Operacao ainda nao realizada.</msg><payment_method>cielows2p_mastercard</payment_method><normalized_payment_met
hod>mastercard</normalized_payment_method><installments>3</installments><value>17169</value><original_value>17169</original_value><trn_type>0</trn_type><cc_number_hash>EXCayM6Skgp84ozWq+6aZjDbWzk=</cc_number_hash><cc_number_masked>548474******4113</cc_num
ber_masked><cc_brand>mastercard</cc_brand><additional_data /><msg_3ds /><msg_avs /><settlement_msg /><last_attempt><status>51</status><normalized_status>-97</normalized_status><msg>5 - Nao autorizada|pan=vBYb9u2Mq65kcK6k6i1idSNA9XLXdj35NTiS769kIPs=</msg><
installments>3</installments><value>17169</value><original_value>17169</original_value><attempt_trn_type>2</attempt_trn_type><cc_number_hash>EXCayM6Skgp84ozWq+6aZjDbWzk=</cc_number_hash><cc_number_masked>548474******4113</cc_number_masked><cc_brand>master
card</cc_brand><aux_number>453293</aux_number><id>10020346526L1N3CD5JB</id><additional_data>Pre-Autorizacao - Host: CIELO Empresa: 00000000 Terminal: 0001 Codigo Rede: null </additional_data><msg_3ds /><msg_avs /></last_attempt></fi></fi_data></payOrderRe
turn>'  
*/        
        
DECLARE @AUX             XML        
DECLARE @ESTADO          NUMERIC(15)        
DECLARE @STATUS_WS       NUMERIC(15)        
DECLARE @REPROCESSA_BPAG VARCHAR(1)        
        
SET @XML = REPLACE(@XML, '<?xml version="1.0" encoding="UTF-8"?>', '')        
        
SET @AUX = CONVERT(XML, @XML)        
        
DECLARE @PROCESSAR VARCHAR(1)  
select @PROCESSAR = CASE WHEN (@AUX.value('(payOrderReturn/msg)[1]','varchar(500)') LIKE '%Connection refused%') or        
                              --(@AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]','numeric(15)') = -105)        
                              (@AUX.value('(payOrderReturn/bpag_data/status)[1]','numeric(15)') = -105)        
                         THEN 'N'        
                         ELSE 'S'        
                    END        
      
DECLARE       
        @UTILIZA_ANALISE_ANTIFRAUDE VARCHAR(1),      
        @OPERADORA_ANTIFRAUDE_PADRAO NUMERIC(15),      
        @ANTIFRAUDE_PLATAFORMA_ATIVA VARCHAR(1)            
        
SELECT TOP 1       
       @UTILIZA_ANALISE_ANTIFRAUDE  = ISNULL(B.UTILIZA_ANALISE_ANTIFRAUDE,'N'),      
       @OPERADORA_ANTIFRAUDE_PADRAO = B.OPERADORA_ANTIFRAUDE_PADRAO ,      
       @ANTIFRAUDE_PLATAFORMA_ATIVA = ISNULL(D.ATIVO,'N')      
      
  FROM PDV_PREVENDAS               A WITH(NOLOCK)      
  JOIN EMPRESAS_USUARIAS           C WITH(NOLOCK) ON C.FILIAL                = A.LOJA      
  JOIN PARAMETROS_VENDAS           B WITH(NOLOCK) ON B.EMPRESA_USUARIA       = C.EMPRESA_USUARIA      
  LEFT JOIN ANTIFRAUDE_PLATAFORMAS D WITH(NOLOCK) ON D.ANTIFRAUDE_PLATAFORMA = CASE WHEN A.PLATAFORMA_ECOMMERCE = 2      
                                                                                    THEN 2 -- RAHDA      
                                                                                    ELSE 1 -- ULTRA      
                                                                               END      
 WHERE A.PREVENDA = @PREVENDA      
                            
IF(@PROCESSAR IS NULL)        
  SET @PROCESSAR = 'N'        
        
-------------------------------------------------------------        
--- VERIFICA O STATUS PARA PARA ENTRAR EM REPROCESSAMENTO        
-------------------------------------------------------------        
SELECT @STATUS_WS       = STATUS_WS        
      ,@REPROCESSA_BPAG = REPROCESSA_BPAG         
  FROM BPAG_STATUS_RETORNOS WITH(NOLOCK)         
 --WHERE STATUS_WS = @AUX.value('(payOrderReturn/status)[1]', 'int')      
 --WHERE STATUS_WS = @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'int')        
 WHERE STATUS_WS = @AUX.value('(payOrderReturn/bpag_data/status)[1]', 'int')        
  
IF @REPROCESSA_BPAG = 'S'        
BEGIN         
  
     UPDATE PREVENDAS_BPAG_PAYORDER        
        SET XML_RETORNO          = NULL,        
            XML_RETORNO_ANTERIOR = @XML,        
            QUANTIDADES_ENVIADAS = QUANTIDADES_ENVIADAS + 1,        
            DATA_HORA            = GETDATE()        
      WHERE ID = @ID         
  
  
     SET @PROCESSAR = 'N'        
  
END         
        
IF (RTRIM(LTRIM(@XML)) <> '') AND (@PROCESSAR = 'S')        
BEGIN        
        
   UPDATE PREVENDAS_BPAG_PAYORDER        
   SET XML_RETORNO          = @AUX,        
          status_ws            = @AUX.value('(payOrderReturn/status)[1]', 'int')               ,        
          prevenda_bpag        = @AUX.value('(payOrderReturn/bpag_data/id)[1]', 'numeric')     ,        
          --status_bpag          = @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'numeric'),        
          status_bpag          = CASE WHEN @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'numeric') IN (1,0)-- 29/03/2023 ADD TIPO 1 (PRE AUTORIZADO). BPAG/LEANCOMMERCE
		                              THEN 0
									  ELSE @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'numeric')
								  END ,        
          --status_bpag          = @AUX.value('(payOrderReturn/bpag_data/status)[1]', 'numeric'),        
          DATA_HORA_RETORNO    = GETDATE(),        
          QUANTIDADES_ENVIADAS = QUANTIDADES_ENVIADAS + 1        
    WHERE ID = @ID         
        
   SELECT @ESTADO = CASE WHEN @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'int') IN (1,0) -- 29/03/2023 ADD TIPO 1 (PRE AUTORIZADO). BPAG/LEANCOMMERCE
   --SELECT @ESTADO = CASE WHEN @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'int') = 0        
   --SELECT @ESTADO = CASE WHEN @AUX.value('(payOrderReturn/bpag_data/status)[1]', 'int') = 0        
                   THEN STATUS_APROVADO        
                   ELSE STATUS_REPROVADO        
                 END         
    FROM PARAMETROS_BPAG A WITH(NOLOCK)        
  
    --colocado aqui pois estava parando varios pedidos com status 101           
    --EXEC GRAVACAO_FINAL_PREVENDA @PREVENDA        
        
   INSERT INTO TELEVENDAS_ESTADO_COMANDAS_LOG (        
    REG_MASTER_ORIGEM,        
    ESTADO,        
    DATA_HORA,        
    PREVENDA,        
    PROCESSO,        
    RESPONSAVEL,        
    OBSERVACAO )        
   SELECT @ID,        
    @ESTADO,        
    GETDATE(),        
    @PREVENDA,        
    'PREAUTORIZACAO',        
    'BPAG',        
    'USP_BPAG_PAYORDER_RETORNO 1'        
   FROM TELEVENDAS_ESTADO_COMANDAS_LOG WITH(NOLOCK)        
     WHERE PREVENDA = @PREVENDA        
    AND ESTADO   = @ESTADO        
    HAVING COUNT(1) = 0        
        
        
   IF @ESTADO = (SELECT STATUS_REPROVADO FROM PARAMETROS_BPAG WITH(NOLOCK))         
   BEGIN        
         
     DELETE PREVENDAS_PENDENTES_IMPRESSOES         
      WHERE PREVENDA_IMPRESSAO in ( SELECT PREVENDA_IMPRESSAO        
              FROM PREVENDAS_PENDENTES_IMPRESSOES WITH(NOLOCK)        
             WHERE PREVENDA =  @PREVENDA )  
                                         
     EXEC USP_NCARTAO_PREVENDA @PREVENDA  
         
   END        
   
 
   IF @ESTADO = (SELECT STATUS_APROVADO FROM PARAMETROS_BPAG WITH(NOLOCK))         
   BEGIN         
        
    IF (@UTILIZA_ANALISE_ANTIFRAUDE = 'S' AND @OPERADORA_ANTIFRAUDE_PADRAO = 2 /* ClearSale */ AND @ANTIFRAUDE_PLATAFORMA_ATIVA = 'S')       
    BEGIN      
      INSERT           
      INTO TELEVENDAS_ESTADO_COMANDAS_LOG           
      (           
        REG_MASTER_ORIGEM,        
        ESTADO,        
        DATA_HORA,        
        PREVENDA,        
        PROCESSO,        
        RESPONSAVEL,        
        OBSERVACAO )        
                
      SELECT TOP 1           
       A.PREVENDA                  AS REG_MASTER_ORIGEM ,          
       2                           AS ESTADO            ,                              
       GETDATE()                   AS DATA_HORA         ,          
       A.PREVENDA                  AS PREVENDA          ,          
       'PREAUTORIZACAO'            AS PROCESSO          ,          
       'BPAG'                      AS RESPONSAVEL       ,          
       'USP_BPAG_PAYORDER_RETORNO 2' AS OBSERVACAO                   
     FROM PDV_PREVENDAS                          A WITH(NOLOCK)          
     LEFT JOIN TELEVENDAS_ESTADO_COMANDAS_LOG    B WITH(NOLOCK) ON B.PREVENDA       = A.PREVENDA          
         AND B.ESTADO         = 2        
     LEFT JOIN ANTIFRAUDE_ENFILEIRAMENTO         D WITH(NOLOCK) ON D.PREVENDA       = A.PREVENDA  
     LEFT JOIN ANALISE_PREVENDAS_CARTOES         G WITH(NOLOCK) ON G.PREVENDA       = A.PREVENDA               
     JOIN TELEVENDAS_ESTADO_COMANDAS             F WITH(NOLOCK) ON F.PREVENDA       = A.PREVENDA        
         AND F.ESTADO         = 101        
       WHERE A.PREVENDA  = @PREVENDA        
      AND B.PREVENDA IS NULL          
      AND D.PREVENDA IS NULL    
      AND G.PREVENDA IS NULL        
      AND A.ORIGEM NOT IN ('B')        
         --AND 1 = 2        
    END      
    ELSE      
    BEGIN      
      INSERT           
      INTO TELEVENDAS_ESTADO_COMANDAS_LOG           
      (           
        REG_MASTER_ORIGEM,        
        ESTADO,        
        DATA_HORA,        
        PREVENDA,        
        PROCESSO,        
        RESPONSAVEL,        
        OBSERVACAO )        
                
      SELECT TOP 1           
       A.PREVENDA                  AS REG_MASTER_ORIGEM ,          
       2                           AS ESTADO            ,                              
       GETDATE()                   AS DATA_HORA         ,          
       A.PREVENDA                  AS PREVENDA          ,          
       'PREAUTORIZACAO'            AS PROCESSO          ,          
       'BPAG'                      AS RESPONSAVEL       ,          
       'USP_BPAG_PAYORDER_RETORNO 3' AS OBSERVACAO                   
     FROM PDV_PREVENDAS                          A WITH(NOLOCK)          
     LEFT JOIN TELEVENDAS_ESTADO_COMANDAS_LOG    B WITH(NOLOCK) ON B.PREVENDA       = A.PREVENDA          
         AND B.ESTADO         = 2        
     LEFT JOIN ANALISE_PREVENDAS_CARTOES         D WITH(NOLOCK) ON D.PREVENDA       = A.PREVENDA       
     LEFT JOIN ANTIFRAUDE_ENFILEIRAMENTO         G WITH(NOLOCK) ON G.PREVENDA       = A.PREVENDA          
     JOIN TELEVENDAS_ESTADO_COMANDAS             F WITH(NOLOCK) ON F.PREVENDA       = A.PREVENDA        
         AND F.ESTADO         = 101        
       WHERE A.PREVENDA  = @PREVENDA        
      AND B.PREVENDA IS NULL          
      AND D.PREVENDA IS NULL  
      AND G.PREVENDA IS NULL          
      AND A.ORIGEM NOT IN ('B')        
         --AND 1 = 2        
    END         
      
         
    -- CASO BPAG RETORNE OK NA PRE-AUTORIZACAO        
    -- E PEDIDO JÁ TENHA STATUS DE LIBERACAO        
    -- JA PODE LIBERAR COMANDA PARA IMPRESSAO        
    INSERT INTO PREVENDAS_PENDENTES_IMPRESSOES ( PREVENDA )        
    SELECT DISTINCT         
        A.PREVENDA           
     FROM PDV_PREVENDAS                        A WITH(NOLOCK)       
     JOIN TELEVENDAS_ESTADO_COMANDAS_LOG       B WITH(NOLOCK) ON B.PREVENDA		   = A.PREVENDA        
													         AND B.ESTADO		   = 2        											   
     JOIN TELEVENDAS_ESTADO                    C WITH(NOLOCK) ON C.ESTADO		   = B.ESTADO                   
     LEFT JOIN PREVENDAS_PENDENTES_IMPRESSOES  D WITH(NOLOCK) ON D.PREVENDA		   = A.PREVENDA        
     LEFT JOIN PDV_PREVENDAS_ITENS             E WITH(NOLOCK) ON E.PREVENDA		   = A.PREVENDA        
     LEFT JOIN TELEVENDAS_ESTADO_COMANDAS_LOG  F WITH(NOLOCK) ON F.PREVENDA		   = A.PREVENDA        
															 AND F.ESTADO		   = 10    
     LEFT JOIN PARAMETROS_ESTOQUE			   G WITH(NOLOCK) ON G.EMPRESA_USUARIA = A.EMPRESA    
     WHERE 1=1        
       AND C.GERAR_IMPRESSAO = 'S'        
       AND D.PREVENDA IS NULL          
       AND A.PREVENDA = @PREVENDA           
       AND F.TELEVENDA_ESTADO_LOG IS NULL  
	   AND ISNULL(G.EMPRESA_WMS,'N') = 'N'
     GROUP BY A.PREVENDA        
    HAVING COUNT(DISTINCT E.PRODUTO) <= 24        
  
    EXEC USP_NCARTAO_PREVENDA @PREVENDA  
  
   END        
            
  
END
GO