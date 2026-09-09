CREATE OR ALTER PROCEDURE dbo.sp_GerarAuthorizationUOL
(
      @AccessId VARCHAR(200)
    , @SecretKeyBase64 VARCHAR(MAX)
    , @HttpVerb VARCHAR(20)
    , @ContentMD5 VARCHAR(200) = ''
    , @ContentType VARCHAR(200) = ''
    , @DateHeader VARCHAR(100)
    , @CanonicalHeaders VARCHAR(MAX) = ''
    , @PathInfo VARCHAR(MAX)
)
AS
BEGIN

    SET NOCOUNT ON;

    SELECT
        HeaderAuthorization =
        dbo.fn_UOLAuthorization(
              @AccessId
            , @SecretKeyBase64
            , @HttpVerb
            , @ContentMD5
            , @ContentType
            , @DateHeader
            , @CanonicalHeaders
            , @PathInfo
        );

END;
GO