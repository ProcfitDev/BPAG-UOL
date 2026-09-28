CREATE OR ALTER PROCEDURE dbo.sp_ProcessarRetornoCancelamentoV3 (
    @PREVENDA NUMERIC(15), 
    @JSON_RETORNO VARCHAR(MAX) 
)        
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StatusRetorno VARCHAR(50);
    DECLARE @OrderId VARCHAR(100);
    DECLARE @ESTADO_CANCELADO NUMERIC(15);

    -- 1. Parse do Retorno JSON V3 do endpoint de Void usando JSON_VALUE
    -- O endpoint de void costuma retornar o status na raiz do JSON
    SET @StatusRetorno = JSON_VALUE(@JSON_RETORNO, '$.status');
    SET @OrderId       = JSON_VALUE(@JSON_RETORNO, '$.id');

    -- 2. Verifica se a adquirente confirmou o cancelamento/estorno
    IF @StatusRetorno IN ('CANCELED', 'VOIDED')
    BEGIN
        -- Atualiza a tabela transacional com o JSON e o status financeiro de recusa/cancelado (-105)[cite: 1]
        UPDATE PREVENDAS_BPAG_PAYORDER        
        SET XML_RETORNO = @JSON_RETORNO,
            status_ws = -105,        
            status_bpag = @StatusRetorno,        
            DATA_HORA_RETORNO = GETDATE()        
        WHERE PREVENDA = @PREVENDA AND (prevenda_bpag = @OrderId OR @OrderId IS NULL);
        
        -- Busca o código de estado correspondente a reprovado/cancelado nos parâmetros[cite: 1]
        SELECT @ESTADO_CANCELADO = STATUS_REPROVADO 
        FROM PARAMETROS_BPAG WITH(NOLOCK);
        
        -- Grava Log de Comandas informando o cancelamento[cite: 1]
        INSERT INTO TELEVENDAS_ESTADO_COMANDAS_LOG (REG_MASTER_ORIGEM, ESTADO, DATA_HORA, PREVENDA, PROCESSO, RESPONSAVEL, OBSERVACAO)        
        SELECT TOP 1 ID, @ESTADO_CANCELADO, GETDATE(), @PREVENDA, 'CANCELAMENTO', 'BPAG', 'SP_PROCESSAR_RETORNO_CANCELAMENTO_V3'        
        FROM PREVENDAS_BPAG_PAYORDER WITH(NOLOCK)
        WHERE PREVENDA = @PREVENDA
        ORDER BY ID DESC;
        
        -- Regras de Negócio de Cancelamento/Recusa: Apaga da esteira de impressão[cite: 1]
        DELETE PREVENDAS_PENDENTES_IMPRESSOES         
        WHERE PREVENDA_IMPRESSAO IN (SELECT PREVENDA_IMPRESSAO FROM PREVENDAS_PENDENTES_IMPRESSOES WITH(NOLOCK) WHERE PREVENDA = @PREVENDA)[cite: 1];  
        
        -- Limpa os dados do cartão gravados na pré-venda por segurança[cite: 1]
        EXEC USP_NCARTAO_PREVENDA @PREVENDA[cite: 1];  
    END
    ELSE
    BEGIN
        -- Caso o cancelamento falhe na adquirente (ex: erro, negado), apenas gravamos o retorno para auditoria
        UPDATE PREVENDAS_BPAG_PAYORDER        
        SET XML_RETORNO = @JSON_RETORNO,
            DATA_HORA_RETORNO = GETDATE()        
        WHERE PREVENDA = @PREVENDA;
    END
END;
GO