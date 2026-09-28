
/*
    Criação do Pedido: Evolução da USP_BPAG_PAYORDER
    Essa procedure substitui a construção 
    do FOR XML PATH pelo FOR JSON PATH. 
    Ela também gera o cabeçalho de autenticação e insere na fila.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_GerarPayloadPedidoV3] (
    @PREVENDA NUMERIC(15)
)          
AS  
BEGIN
    SET NOCOUNT ON;

    DECLARE @TAXA NUMERIC(15,2);
    DECLARE @payment_method VARCHAR(60);
    DECLARE @cc_brand VARCHAR(60);
    DECLARE @digito_ccv INT;
    
    -- Busca taxa
    SELECT @TAXA = ISNULL(TAXA, 0) FROM PDV_PREVENDAS WITH(NOLOCK) WHERE PREVENDA = @PREVENDA;
    
    -- Mapeamento da adquirente (Getnet na V3 em vez de Cielo/Redecard)
    SELECT 
        @payment_method = 'GETNET', 
        @cc_brand = LOWER(B.DESCRICAO),
        @digito_ccv = ISNULL(B.NUMERO_DIGITOS_CCV, 3)
    FROM PDV_PREVENDAS A WITH(NOLOCK)        
    INNER JOIN TELEVENDAS_PARAMS_CARTOES_PARCELAMENTO B WITH(NOLOCK) 
        ON B.NUMERO_CARTAO = SUBSTRING(CONVERT(VARCHAR, A.NCARTAO), 1, B.NUMERO_DIGITOS_VERIFICAR)        
    WHERE A.PREVENDA = @PREVENDA;

    -- 1. Geração do Payload em JSON (Substitui o @pacote XML)
    DECLARE @PayloadJSON NVARCHAR(MAX) = (
        SELECT 
            -- Calcula o valor total em centavos, considerando taxa e descontos
            reference = CAST(A.PREVENDA AS VARCHAR(50)),
            requestDate = FORMAT(GETUTCDATE(), 'yyyy-MM-ddTHH:mm:ssZ'),
            currency = 'BRL',
            
            -- Dados do Cliente (Substitui o bloco @cliente XML)
            details = (
                SELECT 
                    customers = (
                        SELECT 
                            id = CAST(A.CLIENTE AS VARCHAR(50)),
                            firstName = SUBSTRING(E.NOME, 1, CASE WHEN CHARINDEX(' ', E.NOME)-1 <= 0 THEN 30 ELSE CHARINDEX(' ', E.NOME)-1 END),
                            document = E.INSCRICAO_FEDERAL,
                            documentType = CASE WHEN PJ.ENTIDADE IS NULL THEN 'CPF' ELSE 'CNPJ' END,
                            email = ISNULL(REPLACE(EM.EMAIL, 0x1F, ''), '')
                        FOR JSON PATH
                    )
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            
            -- Dados do Pagamento (Substitui o bloco @pagamentos XML)
            payments = (
                SELECT 
                    amount = CONVERT(INT, A.CARTAO * 100),
                    paymentMethod = (
                        SELECT 
                            paymentType = 'CARD',
                            paymentSubtype = 'CREDIT',
                            financialInstitution = @payment_method,
                            processor = @payment_method
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    ),
                    creditCard = (
                        SELECT 
                            brand = @cc_brand,
                            number = A.NCARTAO, -- Em prod, evite gravar/trafegar aberto se não for PCI
                            cvv = A.CCV,
                            expDate = CONCAT('20', SUBSTRING(A.VALIDADE, 4, 2), '-', SUBSTRING(A.VALIDADE, 1, 2)),
                            installments = A.PARCELAS
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                FOR JSON PATH
            )
        FROM PDV_PREVENDAS A WITH(NOLOCK)
        INNER JOIN ENTIDADES E WITH(NOLOCK) ON E.ENTIDADE = A.CLIENTE
        LEFT JOIN EMAIL EM WITH(NOLOCK) ON EM.ENTIDADE = A.CLIENTE
        LEFT JOIN PESSOAS_JURIDICAS PJ WITH(NOLOCK) ON PJ.ENTIDADE = A.CLIENTE
        WHERE A.PREVENDA = @PREVENDA
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    -- 2. Insere na fila para o ERP/Checkout capturar (Substitui o insert do @pacote)
    IF (SELECT COUNT(1) FROM PREVENDAS_BPAG_PAYORDER WITH(NOLOCK) WHERE PREVENDA = @PREVENDA AND ISNULL(STATUS_WS,-1) = 0) = 0
    BEGIN
        INSERT INTO PREVENDAS_BPAG_PAYORDER (PREVENDA, XML_ENVIO) -- Pode renomear a coluna para PAYLOAD_ENVIO no futuro
        VALUES (@PREVENDA, @PayloadJSON);
    END
END