USE [PBS_ULTRAFARMA_HOMOLOG_DADOS]
GO

/****** Object:  Table [dbo].[PARAMETROS_BPAG_V3] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PARAMETROS_BPAG_V3](
    [PARAMETRO_BPAG_V3] [numeric](15, 0) IDENTITY(1,1) NOT NULL,
    [FORMULARIO_ORIGEM] [numeric](6, 0) NULL,
    [TAB_MASTER_ORIGEM] [numeric](6, 0) NULL,
    [REG_MASTER_ORIGEM] [numeric](15, 0) NULL,
    [REG_LOG_INCLUSAO] [numeric](15, 0) NULL,
    [GRUPO_EMPRESARIAL] [numeric](15, 0) NOT NULL,
    
    -- Variáveis de Conexão da V3
    [URL_BASE] [varchar](255) NOT NULL,
    [MERCHANT] [varchar](100) NOT NULL,
    [ACCOUNT] [varchar](100) NOT NULL,
    [ACCESS_ID] [varchar](200) NOT NULL,
    [SECRET_KEY] [varchar](MAX) NOT NULL,
    
    -- Status Financeiros para o ERP
    [STATUS_APROVADO] [numeric](5, 0) NULL,
    [STATUS_REPROVADO] [numeric](5, 0) NULL,
    [STATUS_CANCELAMENTO] [numeric](5, 0) NULL,
    [STATUS_FALHA_CONEXAO] [numeric](5, 0) NULL,
    [ATIVAR_LOG] [varchar](1) NULL,
PRIMARY KEY CLUSTERED 
(
    [PARAMETRO_BPAG_V3] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Insert com as variáveis exatas do ambiente Sandbox (Homologação)
INSERT INTO [dbo].[PARAMETROS_BPAG_V3] (
    [GRUPO_EMPRESARIAL], 
    [URL_BASE], 
    [MERCHANT], 
    [ACCOUNT], 
    [ACCESS_ID], 
    [SECRET_KEY],
    [ATIVAR_LOG]
)
VALUES (
    1, -- Insira o número do Grupo Empresarial correto caso seja diferente
    'https://sandbox-psp.bpag.com.br', 
    'ultrafarma-hml', 
    'ultrafarma-pet-hml', 
    'c23ad060dc0aa175d64c8731296486a7', 
    'PNMD7f2PjkGXntUXrYhGcOvBJJACsOSKPIdcJTPbHn0=', 
    'S'
);
GO