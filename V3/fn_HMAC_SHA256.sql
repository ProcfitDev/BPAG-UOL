CREATE OR ALTER FUNCTION dbo.fn_HMAC_SHA256
(
      @Key VARBINARY(MAX)
    , @Message VARCHAR(MAX)
)
RETURNS VARBINARY(MAX)
AS
BEGIN

    DECLARE @BlockSize INT = 64

    IF DATALENGTH(@Key) > @BlockSize
        SET @Key = HASHBYTES('SHA2_256', @Key)

    IF DATALENGTH(@Key) < @BlockSize
        SET @Key = @Key +
            CONVERT(VARBINARY(MAX),
                REPLICATE(CAST(CHAR(0) AS VARCHAR(MAX)),
                @BlockSize - DATALENGTH(@Key))
            )

    DECLARE @ipad VARBINARY(MAX) = 0x
    DECLARE @opad VARBINARY(MAX) = 0x

    DECLARE @i INT = 1

    WHILE @i <= @BlockSize
    BEGIN

        DECLARE @b INT

        SET @b =
            CAST(
                SUBSTRING(@Key,@i,1)
            AS TINYINT)

        SET @ipad =
            @ipad +
            CAST(@b ^ 54 AS BINARY(1))

        SET @opad =
            @opad +
            CAST(@b ^ 92 AS BINARY(1))

        SET @i += 1

    END

    DECLARE @InnerHash VARBINARY(32)

    SET @InnerHash =
        HASHBYTES(
            'SHA2_256',
            @ipad +
            CONVERT(VARBINARY(MAX),@Message)
        )

    RETURN HASHBYTES(
        'SHA2_256',
        @opad + @InnerHash
    )

END
GO