/*
    Processamento do Retorno: Evolução da USP_BPAG_PAYORDER_RETORNO
    Aqui substituímos o XQuery (@AUX.value) 
    pela leitura de JSON (JSON_VALUE), 
    mas mantem integralmente a sua lógica de antifraude, 
    impressão e log de comandas.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ProcessarRetornoPedidoV3] (
    @ID NUMERIC, 
    @PREVENDA NUMERIC, 
    @JSON_RETORNO VARCHAR(MAX) -- Recebe JSON em vez de XML
)        
AS
BEGIN
    DECLARE @ESTADO NUMERIC(15);
    DECLARE @STATUS_WS NUMERIC(15);
    DECLARE @REPROCESSA_BPAG VARCHAR(1);
    
    -- Variáveis de leitura do JSON
    DECLARE @StatusRetorno VARCHAR(50);
    DECLARE @TransactionId VARCHAR(100);
    DECLARE @NormalizedStatus INT;
    DECLARE @MsgErro VARCHAR(255);

    -- 1. Parse do Retorno JSON V3 usando JSON_VALUE (Substitui @AUX.value)
    SET @StatusRetorno = JSON_VALUE(@JSON_RETORNO, '$.transactions[0].status');
    SET @TransactionId = JSON_VALUE(@JSON_RETORNO, '$.transactions[0].id');
    SET @MsgErro       = JSON_VALUE(@JSON_RETORNO, '$.transactions[0].rawMessage');
    
    -- Converte o status em texto da V3 para o numérico que o seu sistema já usa
    SET @NormalizedStatus = CASE 
        WHEN @StatusRetorno IN ('PRE_AUTHORIZED', 'PAID') THEN 0
        WHEN @StatusRetorno = 'REJECTED' THEN -105 -- Exemplo de recusa
        ELSE -1 
    END;

    DECLARE @PROCESSAR VARCHAR(1) = CASE 
        WHEN @NormalizedStatus = -105 THEN 'N' ELSE 'S' 
    END;
      
    -- Variáveis de Antifraude originais
    DECLARE @UTILIZA_ANALISE_ANTIFRAUDE VARCHAR(1), @OPERADORA_ANTIFRAUDE_PADRAO NUMERIC(15), @ANTIFRAUDE_PLATAFORMA_ATIVA VARCHAR(1);
    
    SELECT TOP 1       
       @UTILIZA_ANALISE_ANTIFRAUDE  = ISNULL(B.UTILIZA_ANALISE_ANTIFRAUDE,'N'),      
       @OPERADORA_ANTIFRAUDE_PADRAO = B.OPERADORA_ANTIFRAUDE_PADRAO,      
       @ANTIFRAUDE_PLATAFORMA_ATIVA = ISNULL(D.ATIVO,'N')      
    FROM PDV_PREVENDAS A WITH(NOLOCK)      
    JOIN EMPRESAS_USUARIAS C WITH(NOLOCK) ON C.FILIAL = A.LOJA      
    JOIN PARAMETROS_VENDAS B WITH(NOLOCK) ON B.EMPRESA_USUARIA = C.EMPRESA_USUARIA      
    LEFT JOIN ANTIFRAUDE_PLATAFORMAS D WITH(NOLOCK) ON D.ANTIFRAUDE_PLATAFORMA = CASE WHEN A.PLATAFORMA_ECOMMERCE = 2 THEN 2 ELSE 1 END      
    WHERE A.PREVENDA = @PREVENDA;
                            
    IF (@PROCESSAR IS NULL) SET @PROCESSAR = 'N';

    -- 2. Verifica status para Reprocessamento
    SELECT 
        @STATUS_WS = STATUS_WS, @REPROCESSA_BPAG = REPROCESSA_BPAG         
    FROM BPAG_STATUS_RETORNOS WITH(NOLOCK)         
    WHERE STATUS_WS = @NormalizedStatus; 

    IF @REPROCESSA_BPAG = 'S'        
    BEGIN         
        UPDATE PREVENDAS_BPAG_PAYORDER        
        SET XML_RETORNO = NULL, XML_RETORNO_ANTERIOR = @JSON_RETORNO, QUANTIDADES_ENVIADAS = QUANTIDADES_ENVIADAS + 1, DATA_HORA = GETDATE()        
        WHERE ID = @ID;         
        SET @PROCESSAR = 'N';
    END;         
        
    -- 3. Atualização Final e Inserção de Logs
    IF (RTRIM(LTRIM(@JSON_RETORNO)) <> '') AND (@PROCESSAR = 'S')        
    BEGIN        
        UPDATE PREVENDAS_BPAG_PAYORDER        
        SET XML_RETORNO = @JSON_RETORNO, -- Pode gravar o JSON na mesma coluna legada temporariamente
            status_ws = @NormalizedStatus,        
            prevenda_bpag = @TransactionId,        
            status_bpag = @NormalizedStatus,        
            DATA_HORA_RETORNO = GETDATE(),        
            QUANTIDADES_ENVIADAS = QUANTIDADES_ENVIADAS + 1        
        WHERE ID = @ID;
        
        -- Mapeia o Estado de Aprovação/Recusa
        SELECT @ESTADO = CASE WHEN @NormalizedStatus = 0 THEN STATUS_APROVADO ELSE STATUS_REPROVADO END         
        FROM PARAMETROS_BPAG A WITH(NOLOCK);
        
        -- Grava Log de Comandas
        INSERT INTO TELEVENDAS_ESTADO_COMANDAS_LOG (REG_MASTER_ORIGEM, ESTADO, DATA_HORA, PREVENDA, PROCESSO, RESPONSAVEL, OBSERVACAO)        
        SELECT @ID, @ESTADO, GETDATE(), @PREVENDA, 'PREAUTORIZACAO', 'BPAG', 'SP_PROCESSAR_RETORNO_V3'        
        FROM TELEVENDAS_ESTADO_COMANDAS_LOG WITH(NOLOCK)        
        WHERE PREVENDA = @PREVENDA AND ESTADO = @ESTADO        
        HAVING COUNT(1) = 0;
        
        -- Regras de Negócio de Recusa (Apaga pendentes de impressão e limpa cartão)
        IF @ESTADO = (SELECT STATUS_REPROVADO FROM PARAMETROS_BPAG WITH(NOLOCK))         
        BEGIN        
             DELETE PREVENDAS_PENDENTES_IMPRESSOES         
             WHERE PREVENDA_IMPRESSAO IN (SELECT PREVENDA_IMPRESSAO FROM PREVENDAS_PENDENTES_IMPRESSOES WITH(NOLOCK) WHERE PREVENDA = @PREVENDA);  
             EXEC USP_NCARTAO_PREVENDA @PREVENDA;  
        END;
   
        -- Regras de Negócio de Aprovação (Antifraude e Impressão)
        IF @ESTADO = (SELECT STATUS_APROVADO FROM PARAMETROS_BPAG WITH(NOLOCK))         
        BEGIN         
            -- ... (Aqui você mantém integralmente o bloco de INSERT no TELEVENDAS_ESTADO_COMANDAS_LOG com estado 2 dependendo do @UTILIZA_ANALISE_ANTIFRAUDE, exatamente como está na linha 144 a 220 da sua procedure original).
            
            -- Liberação para Impressão
            INSERT INTO PREVENDAS_PENDENTES_IMPRESSOES (PREVENDA)        
            SELECT DISTINCT A.PREVENDA           
            FROM PDV_PREVENDAS A WITH(NOLOCK)       
            JOIN TELEVENDAS_ESTADO_COMANDAS_LOG B WITH(NOLOCK) ON B.PREVENDA = A.PREVENDA AND B.ESTADO = 2        											   
            JOIN TELEVENDAS_ESTADO C WITH(NOLOCK) ON C.ESTADO = B.ESTADO                   
            LEFT JOIN PREVENDAS_PENDENTES_IMPRESSOES D WITH(NOLOCK) ON D.PREVENDA = A.PREVENDA        
            LEFT JOIN PDV_PREVENDAS_ITENS E WITH(NOLOCK) ON E.PREVENDA = A.PREVENDA        
            LEFT JOIN TELEVENDAS_ESTADO_COMANDAS_LOG F WITH(NOLOCK) ON F.PREVENDA = A.PREVENDA AND F.ESTADO = 10    
            LEFT JOIN PARAMETROS_ESTOQUE G WITH(NOLOCK) ON G.EMPRESA_USUARIA = A.EMPRESA    
            WHERE C.GERAR_IMPRESSAO = 'S' AND D.PREVENDA IS NULL AND A.PREVENDA = @PREVENDA AND F.TELEVENDA_ESTADO_LOG IS NULL AND ISNULL(G.EMPRESA_WMS,'N') = 'N'
            GROUP BY A.PREVENDA        
            HAVING COUNT(DISTINCT E.PRODUTO) <= 24;  
        
            EXEC USP_NCARTAO_PREVENDA @PREVENDA;  
        END;        
    END;
END;