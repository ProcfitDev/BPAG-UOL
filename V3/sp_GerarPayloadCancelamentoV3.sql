CREATE OR ALTER PROCEDURE dbo.sp_GerarPayloadCancelamentoV3
    @PREVENDA NUMERIC(15)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrderId VARCHAR(100);
    
    -- 1. Resgata o Order ID (ID da transação na BPAG) salvo durante o fluxo de autorização
    SELECT TOP 1 @OrderId = prevenda_bpag 
    FROM PREVENDAS_BPAG_PAYORDER WITH(NOLOCK)
    WHERE PREVENDA = @PREVENDA AND ISNULL(prevenda_bpag, '') <> ''
    ORDER BY ID DESC;

    IF @OrderId IS NULL
    BEGIN
        SELECT StatusExecucao = 'ERRO', Mensagem = 'Transação BPAG (OrderId) não encontrada para esta pré-venda. Não é possível gerar o cancelamento.';
        RETURN;
    END

    -- 2. Parametrização para o endpoint de Cancelamento (Void)
    DECLARE @PathInfo VARCHAR(200) = CONCAT('/upbc-service-fe/v1/order/', @OrderId, '/void');
    DECLARE @HttpVerb VARCHAR(10) = 'PUT';
    DECLARE @ContentType VARCHAR(100) = 'application/json';
    
    -- Credenciais (Sandbox)
    DECLARE @AccessId VARCHAR(200) = 'c23ad060dc0aa175d64c8731296486a7';
    DECLARE @SecretKeyBase64 VARCHAR(MAX) = 'PNMD7f2PjkGXntUXrYhGcOvBJJACsOSKPIdcJTPbHn0=';

    -- 3. Headers UOLWS (Com a compensação temporal de 14 minutos contra o WAF)
    DECLARE @DataCorrigida DATETIME = DATEADD(MINUTE, 14, GETUTCDATE());
    DECLARE @DateHeader VARCHAR(100) = FORMAT(@DataCorrigida, 'ddd, dd MMM yyyy HH:mm:ss \G\M\T', 'en-US');

    DECLARE @AuthorizationHeader VARCHAR(MAX) = dbo.fn_UOLAuthorization(
        @AccessId, @SecretKeyBase64, @HttpVerb, '', @ContentType, @DateHeader, '', @PathInfo
    );

    -- 4. Corpo da requisição exigido pelo PUT (Pode ser vazio para estorno total)
    DECLARE @PayloadJSON VARCHAR(10) = '{}';

    -- 5. Grava na fila de integração para registro/auditoria
    INSERT INTO PREVENDAS_BPAG_PAYORDER (PREVENDA, XML_ENVIO)
    VALUES (@PREVENDA, @PayloadJSON); 

    -- 6. Devolve o Result Set para o ERP (Orquestrador) fazer o disparo HTTP
    SELECT 
        HttpVerb            = @HttpVerb,
        EndpointPath        = @PathInfo,
        AuthorizationHeader = @AuthorizationHeader,
        DateHeader          = @DateHeader,
        ContentType         = @ContentType,
        RequestBody         = @PayloadJSON,
        OrderId             = @OrderId;
END;
GO