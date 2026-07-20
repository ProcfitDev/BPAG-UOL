CREATE PROCEDURE [dbo].[USP_BPAG_CAPTURE] (@PREVENDA NUMERIC(15))        
AS        

DECLARE @TAXA           NUMERIC(15,2)
              
declare @pacote xml = (        
        
--<cancel><merch_ref>40</merch_ref><id>1550812</id></cancel>

SELECT TOP 1 
       A.PREVENDA                     AS 'merch_ref',
       B.PREVENDA_BPAG                AS 'id'
  FROM PDV_PREVENDAS                A WITH(NOLOCK)
 inner JOIN PREVENDAS_BPAG_PAYORDER B WITH(NOLOCK) ON B.PREVENDA = A.PREVENDA
 WHERE A.PREVENDA = @PREVENDA        
  for xml path(''), root('capture')
        
)        
        
INSERT INTO PREVENDAS_BPAG_CANCEL (
       PREVENDA,        
       PREVENDA_BPAG,
       XML_ENVIO)        
SELECT @PREVENDA,        
       @PACOTE.value('(cancel/id)[1]', 'numeric'),
       @PACOTE 

GO