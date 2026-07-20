CREATE PROCEDURE [dbo].[USP_BPAG_PREAUTORIZACAO_MONITOR_EMAIL]
(
       @MONITOR_DBMAIL_REGRA NUMERIC(15),
       @HTML VARCHAR(MAX) OUTPUT
) AS
BEGIN

     SET @HTML = NULL
     ------------------------------------------------------------------------
     -- Declaracao de Variaveis
     ------------------------------------------------------------------------
     DECLARE @QTD_REGISTRO INT = 0
     DECLARE @QTD_REG_PARADOS_TEMPO INT = 0
     DECLARE @QUANTO_TEMPO_SEM_TRANSACAO INT = 0
     DECLARE @REGISTROS TABLE
     (
             ID        INT PRIMARY KEY IDENTITY,
             PREVENDA  NUMERIC(15) NOT NULL,
             DATA_HORA DATETIME NOT NULL 
     )
     DECLARE @DATA_ULTIMA_TRANSACAO DATETIME     
     DECLARE @MSG_VALIDACAO VARCHAR(255) = ''
     
     DECLARE @PROCEDURE_HTML VARCHAR(255) = ''
     DECLARE @ATIVADO VARCHAR(1)
     DECLARE @QTD_LINHAS NUMERIC(15)
     DECLARE @TEMPO_LINHA_PARADA NUMERIC(15)
     DECLARE @TEMPO_SEM_TRANSACAO NUMERIC(15)
     DECLARE @TITULO_EMAIL VARCHAR(60)
     
     DECLARE @HTML_ALERTAS VARCHAR(MAX) = ''
     DECLARE @HTML_TAB_AMOSTRA VARCHAR(MAX) = ''
     DECLARE @HTML_AMOSTRA_REGISTROS VARCHAR(MAX) = ''
     
     ------------------------------------------------------------------------
     --        Selecionando Regras configuradas
     ------------------------------------------------------------------------
     SELECT
            @PROCEDURE_HTML = A.PROCEDURE_HTML,
            @ATIVADO = A.ATIVADO,
            @QTD_LINHAS = A.QTD_LINHAS,
            @TEMPO_LINHA_PARADA = A.TEMPO_LINHA_PARADA,
            @TEMPO_SEM_TRANSACAO = A.TEMPO_SEM_TRANSACAO,
            @TITULO_EMAIL = A.DESCRICAO
            
     FROM MONITOR_DBMAIL_REGRAS A WITH(NOLOCK) 
     WHERE A.MONITOR_DBMAIL_REGRA = @MONITOR_DBMAIL_REGRA
     
     ------------------------------------------------------------------------
     --        Validacoes
     ------------------------------------------------------------------------
     IF @PROCEDURE_HTML IS NULL
     BEGIN
          SET @MSG_VALIDACAO = 'Registro do Formulário Regras do Monitor DBMAIL, não encontrado. (@MONITOR_DBMAIL_REGRA)'
          RAISERROR(@MSG_VALIDACAO,11,-1)
          RETURN
     END
     
     IF @PROCEDURE_HTML <> OBJECT_NAME(@@PROCID)
     BEGIN
          SET @MSG_VALIDACAO = 'Procedure diferente da que está no Formulário de Regras do Monitor DBMail.'
          RAISERROR(@MSG_VALIDACAO,11,-1)
          RETURN
     END
     
     IF @PROCEDURE_HTML <> OBJECT_NAME(@@PROCID)
     BEGIN
          PRINT 'MONITOR_DBMAIL_REGRA '+ CONVERT(VARCHAR(15),@MONITOR_DBMAIL_REGRA) +' não está ativo no momento.'
          RETURN
     END
     
     ------------------------------------------------------------------------
     --                Aplicando Regras de Alertas
     ------------------------------------------------------------------------
     -- Quantidade de registros pendentes
     SELECT
            @QTD_REGISTRO = COUNT(A.PREVENDA)
   
     FROM VW_BPAG_PENDENTE_PREAUTORIZACAO A WITH(NOLOCK)
     
     -- Quantidade de registros pendentes a mais de X horas
     SELECT
            @QTD_REG_PARADOS_TEMPO = COUNT(DISTINCT A.PREVENDA)
   
     FROM VW_BPAG_PENDENTE_PREAUTORIZACAO A WITH(NOLOCK)
     WHERE DATEDIFF(HOUR,A.DATA_HORA, GETDATE()) > @TEMPO_LINHA_PARADA
       AND ISNULL(@TEMPO_LINHA_PARADA,0) > 0
     
     -- Data da ultima transacao
     SELECT 
            @DATA_ULTIMA_TRANSACAO = MAX(A.DATA_HORA)
     FROM PREVENDAS_BPAG_PAYORDER A WITH(NOLOCK)
     WHERE A.XML_RETORNO IS NOT NULL
     
     -- Quanto tempo sem transacao com sucesso
     SELECT 
            @QUANTO_TEMPO_SEM_TRANSACAO = DATEDIFF(HOUR,@DATA_ULTIMA_TRANSACAO, GETDATE())
            
     WHERE DATEDIFF(HOUR,@DATA_ULTIMA_TRANSACAO, GETDATE()) > @TEMPO_SEM_TRANSACAO
       AND ISNULL(@TEMPO_SEM_TRANSACAO,0) > 0
       AND @DATA_ULTIMA_TRANSACAO IS NOT NULL
   
     ------------------------------------------------------------------------
     --           Formando conteudo do email em HTML
     ------------------------------------------------------------------------
     
     IF @QTD_REGISTRO > @QTD_LINHAS
     BEGIN
          SET @HTML_ALERTAS += '<li>Foram encontradas '+ CONVERT(VARCHAR(15),@QTD_REGISTRO) +' registro pendente para serem pré-autorizados.</li><br>'
          
          -- Amostra de registros
          SELECT TOP 10
                 @HTML_AMOSTRA_REGISTROS += '<tr><td>'+CONVERT(VARCHAR(15),A.PREVENDA)+'</td><td>'+CONVERT(VARCHAR(17),A.DATA_HORA,113)+'</td></tr>'                 
   
          FROM VW_FCONTROL_PEDIDOS_SEM_CAPTURA A WITH(NOLOCK)
          ORDER BY A.DATA_HORA
          
          SET @HTML_TAB_AMOSTRA = '<table border="1" bordercolor="#000" cellpadding="5" cellspacing="0" style="font-family:arial;font-size:12px;text-align:center;" ><caption><h3>Amostra de Registros</h3></caption><th bgcolor="#E8E8E8">Prevenda</th><th bgcolor="#E8E8E8">Data Hora</th>'+ @HTML_AMOSTRA_REGISTROS +'</table>'
     END
     
     IF @QTD_REG_PARADOS_TEMPO > 0
     BEGIN
          SET @HTML_ALERTAS += '<li>'+ CONVERT(VARCHAR(15),@QTD_REG_PARADOS_TEMPO) +' pedidos pendentes a mais de '+ CONVERT(VARCHAR(15),@TEMPO_LINHA_PARADA) +' horas.</li><br>'
     END
     
     IF @QUANTO_TEMPO_SEM_TRANSACAO > 0
     BEGIN
          SET @HTML_ALERTAS += '<li>Faz '+ CONVERT(VARCHAR(15),@QUANTO_TEMPO_SEM_TRANSACAO) +' horas que não há nenhuma ocorrência de pré-autorização.</li><br>'
     END
     
     IF @QUANTO_TEMPO_SEM_TRANSACAO > 0 AND @DATA_ULTIMA_TRANSACAO IS NOT NULL
     BEGIN
          SET @HTML_ALERTAS += '<li>Ultima pré-autorização aconteceu em: '+ CONVERT(VARCHAR(17),@DATA_ULTIMA_TRANSACAO,113) +'.</li>'
     END
     
     IF @HTML_ALERTAS <> '' AND @QTD_REGISTRO = 0
     BEGIN
          SET @HTML_ALERTAS += '<br><li>Não foi encontrado nenhum pedido para ser pré-autorizado.</li>'
     END
     
     IF @HTML_ALERTAS <> ''
     BEGIN
          SET @HTML = '<html>   <body style="font-family:arial;font-size:12px;">  <table>  <tr>   <td>    <img src="http://www.procfit.com.br/images/logo.png" width="233" height="87" />   </td>   <td>       <h3>DATABASE MAIL</h3> </TITULO_EMAIL>   </td>  </tr>  </table>  <hr>  <table border="1" bordercolor="#000" cellpadding="5" cellspacing="0" style="font-family:arial;font-size:12px;text-align:center;" >  <tr>   <td>Registro da Regra: </MONITOR_DBMAIL_REGRA> </td><td>Data e-mail: </DATA_FORMACAO_EMAIL></td>  </tr>  </table>  <p><br>  <h3>Alertas:</h3>  <ul>  </HTML_ALERTAS>  </ul>  <br><br>  </HTML_TAB_AMOSTRA>  </body>      </html>'
          SET @HTML = REPLACE(@HTML,'</TITULO_EMAIL>',@TITULO_EMAIL)
          SET @HTML = REPLACE(@HTML,'</MONITOR_DBMAIL_REGRA>',@MONITOR_DBMAIL_REGRA)
          SET @HTML = REPLACE(@HTML,'</DATA_FORMACAO_EMAIL>',CONVERT(VARCHAR(17),GETDATE(),113))
          SET @HTML = REPLACE(@HTML,'</HTML_ALERTAS>',@HTML_ALERTAS)
          
          IF @HTML_TAB_AMOSTRA <> ''
             SET @HTML = REPLACE(@HTML,'</HTML_TAB_AMOSTRA>',@HTML_TAB_AMOSTRA)
     END
   
END
GO