CREATE OR ALTER FUNCTION dbo.fn_VarbinaryToBase64
(
    @Bin VARBINARY(MAX)
)
RETURNS VARCHAR(MAX)
AS
BEGIN

    RETURN (
        SELECT CAST(N'' AS XML).value(
            'xs:base64Binary(sql:variable("@Bin"))',
            'VARCHAR(MAX)'
        )
    )

END
GO