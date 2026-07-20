CREATE PROCEDURE [dbo].[USP_BPAG_PAYORDER_RETORNO_REGRAVAR](@ID NUMERIC, @PREVENDA NUMERIC, @XML VARCHAR(MAX))    
AS    
    
DECLARE @AUX    XML    
DECLARE @ESTADO NUMERIC(15)    
    
SET @XML = REPLACE(@XML, '<?xml version="1.0" encoding="UTF-8"?>', '')    
    
SET @AUX = CONVERT(XML, @XML)    
  
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
    
IF RTRIM(LTRIM(@XML)) <> ''    
BEGIN    
    
      SELECT @ESTADO = CASE WHEN @AUX.value('(payOrderReturn/fi_data/fi/last_attempt/normalized_status)[1]', 'int') = 0--CASE WHEN @AUX.value('(payOrderReturn/status)[1]', 'int') = 0    
                            THEN STATUS_APROVADO    
                            ELSE STATUS_REPROVADO    
                       END     
       FROM PARAMETROS_BPAG A WITH(NOLOCK)    
             
         
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
          'USP_BPAG_PAYORDER_RETORNO'    
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
				      'USP_BPAG_PAYORDER_RETORNO' AS OBSERVACAO               
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
				              --AND 1 = 2   END  
				
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
				      'USP_BPAG_PAYORDER_RETORNO' AS OBSERVACAO               
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
			     JOIN TELEVENDAS_ESTADO_COMANDAS_LOG       B WITH(NOLOCK) ON B.PREVENDA = A.PREVENDA    
			                                                             AND B.ESTADO   = 2    
			     JOIN TELEVENDAS_ESTADO                    C WITH(NOLOCK) ON C.ESTADO   = B.ESTADO               
			     LEFT JOIN PREVENDAS_PENDENTES_IMPRESSOES  D WITH(NOLOCK) ON D.PREVENDA = A.PREVENDA    
			     LEFT JOIN PDV_PREVENDAS_ITENS             E WITH(NOLOCK) ON E.PREVENDA = A.PREVENDA    
			     LEFT JOIN TELEVENDAS_ESTADO_COMANDAS_LOG  F WITH(NOLOCK) ON F.PREVENDA = A.PREVENDA    
			                                                             AND F.ESTADO   = 10 
			     LEFT JOIN PARAMETROS_ESTOQUE			   G WITH(NOLOCK) ON G.EMPRESA_USUARIA = A.EMPRESA  

  		        WHERE 1=1    
			      AND C.GERAR_IMPRESSAO = 'S'    
			      AND D.PREVENDA IS NULL      
			      AND A.PREVENDA = @PREVENDA       
			      AND F.TELEVENDA_ESTADO_LOG IS NULL    
				  AND ISNULL(G.EMPRESA_WMS,'N') = 'N'
  		        GROUP BY A.PREVENDA    
			   HAVING COUNT(DISTINCT E.PRODUTO) <= 24    
			                        
		        
		 END    
        
    
END 
GO