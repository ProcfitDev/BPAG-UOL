CREATE OR ALTER PROCEDURE dbo.sp_GerarPayloadPedidoV3
(
    @PedidoID INT
)
AS
BEGIN
    SET NOCOUNT ON

    -- Credenciais (Sandbox BPAG)
    DECLARE @Merchant VARCHAR(100) = 'ultrafarma-hml'
    DECLARE @Account VARCHAR(100) = 'ultrafarma-hml'
    DECLARE @AccessId VARCHAR(200) = 'c23ad060dc0aa175d64c8731296486a7'
    DECLARE @SecretKeyBase64 VARCHAR(MAX) = 'PNMD7f2PjkGXntUXrYhGcOvBJJACsOSKPIdcJTPbHn0='
    
    DECLARE @HttpVerb VARCHAR(20) = 'POST'
    DECLARE @PathInfo VARCHAR(MAX) = '/upbc-service-fe/v1/order/purchase'
    
    -- Formato de data
    DECLARE @DateHeader VARCHAR(100) = FORMAT(GETUTCDATE(), 'ddd, dd MMM yyyy HH:mm:ss \G\M\T', 'en-US')
    
    DECLARE @HeaderAuthorization VARCHAR(MAX)
    DECLARE @PayloadJSON NVARCHAR(MAX)

    -- Gerar a assinatura consumindo a função já criada
    SET @HeaderAuthorization = dbo.fn_UOLAuthorization(
        @AccessId, @SecretKeyBase64, @HttpVerb, '', '', @DateHeader, '', @PathInfo
    )

    -- Gerar o Payload JSON
    SET @PayloadJSON = (
        SELECT 
            amount = 1000, -- R$ 10,00 (enviado em centavos)
            reference = CAST(@PedidoID AS VARCHAR(50)),
            requestDate = FORMAT(GETUTCDATE(), 'yyyy-MM-ddTHH:mm:ssZ'),
            currency = 'BRL',
            
            -- Detalhes do Cliente
            details = (
                SELECT 
                    customers = (
                        SELECT 
                            id = '12345',
                            firstName = 'Teste',
                            lastName = 'Homologacao',
                            document = '80187630623',
                            documentType = 'CPF',
                            email = 'teste@procfit.com'
                        FOR JSON PATH
                    )
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),

            -- Array de Pagamentos
            payments = (
                SELECT 
                    amount = 1000,
                    paymentMethod = (
                        SELECT 
                            paymentType = 'CARD',
                            paymentSubtype = 'CREDIT',
                            financialInstitution = 'GETNET', 
                            processor = 'GETNET'
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    ),
                    creditCard = (
                        SELECT 
                            brand = 'mastercard',
                            number = '5447318879391031', 
                            cvv = '528',
                            expDate = '2029-02', -- ATENÇÃO: Data de vencimento sempre no futuro
                            holder = 'TESTE HOMOLOGACAO',
                            installments = 1
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                FOR JSON PATH
            )
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )

    -- Retorno para a aplicação consumir
    SELECT 
        RequestBody = @PayloadJSON, 
        AuthorizationHeader = @HeaderAuthorization, 
        DateHeader = @DateHeader,
        MerchantHeader = @Merchant,
        AccountHeader = @Account
END
GO