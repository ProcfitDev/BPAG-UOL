CREATE PROCEDURE [dbo].[USP_BPAG_CANCEL] (@PREVENDA NUMERIC(15), @ESTORNO VARCHAR(1) = 'N')        
AS        
        
declare @pacote xml = (        
        
--<cancel><merch_ref>40</merch_ref><id>1550812</id></cancel>

SELECT TOP 1 
       A.PREVENDA                     AS 'merch_ref',
       B.PREVENDA_BPAG                AS 'id'
  FROM PDV_PREVENDAS                A WITH(NOLOCK)
 inner JOIN PREVENDAS_BPAG_PAYORDER B WITH(NOLOCK) ON B.PREVENDA = A.PREVENDA
 WHERE A.PREVENDA = @PREVENDA   
  ORDER BY ID      
  for xml path(''), root('cancel')
        
)        

IF @PACOTE IS NOT NULL
BEGIN

	INSERT INTO PREVENDAS_BPAG_CANCEL (
		   PREVENDA,        
		   PREVENDA_BPAG,
		   XML_ENVIO,
		   ESTORNO)        
	SELECT @PREVENDA,        
		   @PACOTE.value('(cancel/id)[1]', 'numeric'),
		   @PACOTE ,
		   @ESTORNO
END
GO