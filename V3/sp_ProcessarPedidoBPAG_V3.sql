CREATE OR ALTER PROCEDURE dbo.sp_ProcessarPedidoBPAG_V3
    @PREVENDA NUMERIC(15)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Declaração das variáveis de ambiente e credenciais
    DECLARE @BaseUrl VARCHAR(255);
    DECLARE @Merchant VARCHAR(100);
    DECLARE @Account VARCHAR(100); 
    DECLARE @AccessId VARCHAR(200);
    DECLARE @SecretKeyBase64 VARCHAR(MAX);
    
    -- Busca os parâmetros configurados de forma dinâmica na nova tabela
    SELECT TOP 1 
        @BaseUrl = URL_BASE,
        @Merchant = MERCHANT,
        @Account = ACCOUNT,
        @AccessId = ACCESS_ID,
        @SecretKeyBase64 = SECRET_KEY
    FROM PARAMETROS_BPAG_V3 WITH(NOLOCK);

    -- Trava de segurança caso a tabela não tenha sido populada
    IF @BaseUrl IS NULL
    BEGIN
        SELECT StatusExecucao = 'ERRO', Mensagem = 'Parâmetros da BPAG V3 não encontrados na tabela PARAMETROS_BPAG_V3.';
        RETURN;
    END

    -- 2. Endpoints e Rotas
    DECLARE @PathInfo VARCHAR(200) = '/upbc-service-fe/v1/order/purchase';
    DECLARE @HttpVerb VARCHAR(10) = 'POST';
    DECLARE @UrlCompleta VARCHAR(400) = CONCAT(@BaseUrl, @PathInfo);

    -- 3. Headers UOLWS (Com compensação temporal de 14 minutos para o WAF)
    DECLARE @DataCorrigida DATETIME = DATEADD(MINUTE, 14, GETUTCDATE());
    DECLARE @DateHeader VARCHAR(100) = FORMAT(@DataCorrigida, 'ddd, dd MMM yyyy HH:mm:ss \G\M\T', 'en-US');
    DECLARE @ContentType VARCHAR(100) = 'application/json';
    
    DECLARE @AuthorizationHeader VARCHAR(MAX) = dbo.fn_UOLAuthorization(
        @AccessId, @SecretKeyBase64, @HttpVerb, '', @ContentType, @DateHeader, '', @PathInfo
    );

    -- 4. Resgata o Payload estruturado gerado pela sp_GerarPayloadPedidoV3
    DECLARE @PayloadJSON NVARCHAR(MAX);
    SELECT TOP 1 @PayloadJSON = XML_ENVIO 
    FROM PREVENDAS_BPAG_PAYORDER WITH(NOLOCK) 
    WHERE PREVENDA = @PREVENDA ORDER BY ID DESC;

    -- 5. Disparo via WinHttp (para evitar a injeção oculta de charset)
    DECLARE @Object INT, @HResult INT, @HttpStatus INT;
    DECLARE @ResponseBody NVARCHAR(MAX), @StatusTransacao VARCHAR(50), @TransactionId VARCHAR(100), @RawMessage VARCHAR(255);

    EXEC @HResult = sp_OACreate 'WinHttp.WinHttpRequest.5.1', @Object OUT;
    EXEC @HResult = sp_OAMethod @Object, 'open', NULL, @HttpVerb, @UrlCompleta, 0;

    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'User-Agent', 'Procfit-ERP/1.0';
    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', @ContentType;
    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Authorization', @AuthorizationHeader;
    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Date', @DateHeader;
    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Merchant', @Merchant;
    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Account', @Account;
    EXEC @HResult = sp_OAMethod @Object, 'setRequestHeader', NULL, 'OnBehalfOfAccessId', @AccessId;

    EXEC @HResult = sp_OAMethod @Object, 'send', NULL, @PayloadJSON;
    EXEC @HResult = sp_OAGetProperty @Object, 'status', @HttpStatus OUT;

    CREATE TABLE #TmpResponse (Response NVARCHAR(MAX));
    INSERT INTO #TmpResponse EXEC sp_OAGetProperty @Object, 'responseText';
    SELECT TOP 1 @ResponseBody = Response FROM #TmpResponse;
    DROP TABLE #TmpResponse;
    EXEC sp_OADestroy @Object;

    -- 6. Parse da Resposta (Lê o JSON devolvido)
    IF (ISJSON(@ResponseBody) = 1)
    BEGIN
        SELECT TOP 1 @StatusTransacao = T.status, @TransactionId = T.id, @RawMessage = T.rawMessage
        FROM OPENJSON(@ResponseBody) WITH (transactions NVARCHAR(MAX) AS JSON) A
        CROSS APPLY OPENJSON(A.transactions) WITH (id VARCHAR(100) '$.id', status VARCHAR(50) '$.status', rawMessage VARCHAR(255) '$.rawMessage') T;
    END;

    -- 7. Encaminha para a procedure de retorno registrar a aprovação/recusa nas tabelas
    IF ISNULL(@TransactionId, '') <> '' 
    BEGIN
        DECLARE @FilaID NUMERIC = (SELECT TOP 1 ID FROM PREVENDAS_BPAG_PAYORDER WITH(NOLOCK) WHERE PREVENDA = @PREVENDA ORDER BY ID DESC);
        EXEC sp_ProcessarRetornoPedidoV3 @ID = @FilaID, @PREVENDA = @PREVENDA, @JSON_RETORNO = @ResponseBody;
    END

    -- Output de log para testes
    SELECT 
        PREVENDA = @PREVENDA, 
        HttpStatus = @HttpStatus, 
        StatusTransacao = ISNULL(@StatusTransacao, 'DESCONHECIDO'), 
        MensagemRetorno = @RawMessage,
        PayloadEnviado = @PayloadJSON;
END;
GO