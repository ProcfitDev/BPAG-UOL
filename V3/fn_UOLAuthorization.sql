CREATE OR ALTER FUNCTION dbo.fn_UOLAuthorization
(
      @AccessId VARCHAR(200)
    , @SecretKeyBase64 VARCHAR(MAX)
    , @HttpVerb VARCHAR(20)
    , @ContentMD5 VARCHAR(200)
    , @ContentType VARCHAR(200)
    , @DateHeader VARCHAR(100)
    , @CanonicalHeaders VARCHAR(MAX)
    , @PathInfo VARCHAR(MAX)
)
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @StringToSign VARCHAR(MAX)
    DECLARE @Secret VARBINARY(MAX)
    DECLARE @Signature VARBINARY(MAX)
    DECLARE @SignatureBase64 VARCHAR(MAX)

    SET @StringToSign =
          ISNULL(@HttpVerb,'')+ CHAR(10)
        + ISNULL(@ContentMD5,'') + CHAR(10)
        + ISNULL(@ContentType,'') + CHAR(10)
        + ISNULL(@DateHeader,'') + CHAR(10)
        + ISNULL(@CanonicalHeaders,'')
        + ISNULL(@PathInfo,'')

    SET @Secret =
        dbo.fn_Base64ToVarbinary(
            @SecretKeyBase64
        )

    SET @Signature =
        dbo.fn_HMAC_SHA256(
              @Secret
            , @StringToSign
        )

    SET @SignatureBase64 =
        dbo.fn_VarbinaryToBase64(
            @Signature
        )

    RETURN
          'UOLWS '
        + @AccessId
        + ':'
        + @SignatureBase64
        + ':s2:0.2'

END
GO