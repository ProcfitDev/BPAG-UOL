CREATE PROCEDURE [dbo].[USP_BPAG_PAYORDER] (@PREVENDA NUMERIC(15))          
AS  
  
DECLARE @TAXA           NUMERIC(15,2)  
declare @ITEM           NUMERIC(15)  
declare @certificado    varchar(255)        
declare @payment_method varchar(60)        
declare @cc_brand       varchar(60)        
declare @digito_ccv     int
        
set     @certificado = (SELECT CAMINHO_CERTIFICADO FROM PARAMETROS_BPAG)  

    
----------------------------------------------------------------    
-- PROFISSIONAL: IGOR GRAVA
-- DATA        : 22/04/2014
-- HORA        : 12:10
----------------------------------------------------------------
-- NA SELECT ABAIXO FOI ALTERADO O CAMPO order_subtotal
-- O MESMO ESTAVA SENDO FEITO DA SEGUINTE FORMA:
--    *** CONVERT(INT, (A.TOTAL_LIQUIDO + ISNULL(A.TAXA,0))*100)
-- FOI ALTERADO PARA:
--    *** CONVERT(INT, (A.TOTAL_LIQUIDO + ISNULL(A.TAXA,0))*100)
----------------------------------------------------------------
-- ESTAVA OCORRENDO PROBLEMA COM VENDAS QUE POSSUEM VALE CREDITO
----------------------------------------------------------------
-- 19-08-2014	FURLAN	CASE PARA ENTRAR AMEX E ELO PELA CIELO
--    					tratamento para formatar o ccv @digito_ccv
--                      retirado a condicao do amex no final cc_brand
-- 28-11-2018   BRUNO   ADICIONADO A FORMA DE PAGAMENTO CONVENIO NO DESCONTO
    
declare @itens  xml  
  
declare @pacote xml = (          
          
SELECT A.PREVENDA                     AS 'merch_ref',  
       'call center'                  AS 'origin',  
       'BRL'                          AS 'currency',  
       '0'                            AS 'tax_freight',  
       CONVERT(INT, (  (ISNULL(A.VALE_CREDITO,0) + ISNULL(A.VALE_CREDITO_FIDELIDADE,0) + ISNULL(A.CONVENIO,0))*-1)*100) AS 'discount_plus' ,
       CONVERT(INT, (A.TOTAL_LIQUIDO + ISNULL(A.TAXA,0))*100)   AS 'order_subtotal',  
       CONVERT(INT, (A.CARTAO)*100)   AS 'order_total'  
  FROM PDV_PREVENDAS A WITH(NOLOCK)           
 WHERE A.PREVENDA = @PREVENDA          
  for xml path('order_data'), root('payOrder')           
          
)          
          
SELECT @TAXA = TAXA  
  FROM PDV_PREVENDAS A WITH(NOLOCK)  
 WHERE A.PREVENDA = @PREVENDA          
  
IF @TAXA IS NULL  
   SET @TAXA = 0  
  
SELECT @ITEM = MIN(ITEM)  
  FROM PDV_PREVENDAS_ITENS A WITH(NOLOCK)  
 WHERE A.PREVENDA = @PREVENDA          
  
  
IF (SELECT COUNT(1)   
      FROM PDV_PREVENDAS_ITENS   
     WHERE PREVENDA = @PREVENDA   
       AND QUANTIDADE < 0) = 0  
BEGIN  
  
SET @itens = (           
  
 SELECT PRODUTO AS 'code',          
        DESCRICAO AS 'description' ,          
        QUANTIDADE AS 'units',          
        VALOR AS 'unit_value'          
  FROM (  
 SELECT A.PRODUTO                          ,  
        B.DESCRICAO                        ,  
        CONVERT(INT, A.QUANTIDADE)         AS QUANTIDADE        ,  
        CONVERT(INT, (A.PRECO_LIQUIDO)*100) AS VALOR  
   FROM PDV_PREVENDAS_ITENS A          
  INNER JOIN PRODUTOS       B ON B.PRODUTO = A.PRODUTO          
  WHERE A.PREVENDA = @PREVENDA          
  
UNION ALL  
  
SELECT  '1'                          AS PRODUTO,  
        'TAXA'                        AS DESCRICAO,  
        1         AS QUANTIDADE,    
        CONVERT(INT, (@TAXA)*100)  AS VALOR   
 WHERE @TAXA > 0 ) A  
    for xml path('order_item'), ROOT('order_items')          
)    
        
END  
ELSE  
BEGIN  
  
SET @itens = (           
  
 SELECT PRODUTO AS 'code',          
        DESCRICAO AS 'description' ,          
        QUANTIDADE AS 'units',          
        VALOR AS 'unit_value'          
  FROM (  
 SELECT 0                   AS PRODUTO    ,  
        'PRODUTO DEVOLUCAO' AS DESCRICAO  ,  
        1                   AS QUANTIDADE ,  
        CONVERT(INT, (A.TOTAL_LIQUIDO)*100) AS VALOR  
   FROM PDV_PREVENDAS A          
  WHERE A.PREVENDA = @PREVENDA          
  
UNION ALL  
  
SELECT  '1'                          AS PRODUTO,  
        'TAXA'                        AS DESCRICAO,  
        1         AS QUANTIDADE,    
        CONVERT(INT, (@TAXA)*100)  AS VALOR   
 WHERE @TAXA > 0 ) A  
    for xml path('order_item'), ROOT('order_items')          
)    
  
END        
  
        
        
--SELECT @payment_method = 'sitef_' + LOWER(B.DESCRICAO),      -- HOMOLOGACAO  
--SELECT @payment_method = CASE WHEN B.DESCRICAO IN ( 'AMEX','ELO')
--                              THEN 'cielows2p_' + LOWER(B.DESCRICAO)
--                              ELSE 'redecard_ws_' + LOWER(B.DESCRICAO)
--                         END,
SELECT @payment_method = 'cielows2p_' + LOWER(B.ADQUIRENTE),
                         --'redecard_ws_' + LOWER(B.DESCRICAO),        
       @cc_brand       = LOWER(B.DESCRICAO)  
      ,@digito_ccv     = ISNULL(B.NUMERO_DIGITOS_CCV,3)
             
  FROM PDV_PREVENDAS                               A        
 INNER JOIN TELEVENDAS_PARAMS_CARTOES_PARCELAMENTO B ON B.NUMERO_CARTAO = SUBSTRING(CONVERT(VARCHAR,A.NCARTAO), 1, B.NUMERO_DIGITOS_VERIFICAR)        
 where A.PREVENDA = @PREVENDA        
        
          
DECLARE @pagamentos XML = (          
          
SELECT @payment_method                   AS 'payment_method',          
       a.PARCELAS                        AS 'installments',          
       CONVERT(INT, A.CARTAO*100)        AS 'payment_value',          
       @cc_brand                         AS 'cc_brand',                    
       dbo.X509(a.ncartao, @certificado) AS 'cc_number',          
       dbo.X509(REPLICATE('0', @digito_ccv - len(CCV)) + convert(varchar(5), ccv), @certificado)     AS 'cc_cvv',                 
       substring(a.validade,1,2)         AS 'cc_exp_month',          
       '20' + substring(a.validade,4,2)  AS 'cc_exp_year',          
       a.validade                        AS 'cc_exp'          
  FROM PDV_PREVENDAS            A WITH(NOLOCK)           
 WHERE A.PREVENDA = @PREVENDA          
  for xml path('payment'), root('payment_data')           
)          
          
          
declare @cliente XML = (          
          
SELECT TOP 1   
       A.CLIENTE                                        AS 'customer_id',          
       SUBSTRING(B.NOME, 1, case when charindex(' ', b.nome)-1 <= 0           
                                 then 30          
                                 else charindex(' ', b.nome)-1          
                            end           
       )                                       AS 'customer_info/first_name',          
       SUBSTRING(B.NOME, charindex(' ', B.NOME)+1, 30)  AS 'customer_info/middle_name',          
       ISNULL(REPLACE(C.EMAIL, 0x1F, '') ,'') AS 'customer_info/email',          
       CASE WHEN D.ENTIDADE IS NULL          
            THEN '0'           
            ELSE '1'          
       END                                              AS 'customer_info/document_type',          
    b.INSCRICAO_FEDERAL                                 as 'customer_info/document'          
  FROM PDV_PREVENDAS          A          
 INNER JOIN ENTIDADES         B ON B.ENTIDADE = A.CLIENTE          
  left join EMAIL             C ON C.ENTIDADE = A.CLIENTE          
  left join PESSOAS_JURIDICAS D ON D.ENTIDADE = A.CLIENTE          
 WHERE A.PREVENDA = @PREVENDA           
   for xml path(''), root('customer_data')           
)          
          
SET @pacote.modify('insert sql:variable("@itens")      as last  into  (/payOrder/order_data)[1]')          
SET @pacote.modify('insert sql:variable("@pagamentos") as last  into  (/payOrder)[1]')          
SET @pacote.modify('insert sql:variable("@cliente")    as last  into  (/payOrder)[1]')          



--if (UPPER(@cc_brand) <> 'AMEX') and (SELECT COUNT(1) 
--                                       FROM PREVENDAS_BPAG_PAYORDER A WITH(NOLOCK) 
--                                      WHERE PREVENDA = @PREVENDA 
--                                        AND ISNULL(STATUS_WS,-1) = 0) = 0
if (SELECT COUNT(1) 
      FROM PREVENDAS_BPAG_PAYORDER A WITH(NOLOCK) 
     WHERE PREVENDA = @PREVENDA 
       AND ISNULL(STATUS_WS,-1) = 0) = 0
begin

 	 INSERT INTO PREVENDAS_BPAG_PAYORDER (          
 	 	    PREVENDA,          
		    XML_ENVIO)          
	 SELECT @PREVENDA,          
		    @PACOTE   

end
GO