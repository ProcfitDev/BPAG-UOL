CREATE OR ALTER FUNCTION dbo.fn_Base64ToVarbinary
(
    @Base64 VARCHAR(MAX)
)
RETURNS VARBINARY(MAX)
AS
BEGIN

    RETURN CAST(
        CAST(N'' AS XML).value(
            'xs:base64Binary(sql:variable("@Base64"))',
            'VARBINARY(MAX)'
        )
    AS VARBINARY(MAX))

END
GO