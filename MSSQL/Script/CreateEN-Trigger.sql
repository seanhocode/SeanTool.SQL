DECLARE @SQL NVARCHAR(MAX)
DECLARE @TableName NVARCHAR(MAX)
DECLARE @Count BIGINT = 1
DECLARE @Divider VARCHAR(102) = '--===================================================================================================='
DECLARE @TotalTables BIGINT = 0
DECLARE @Tables TABLE(
    TableIndex BIGINT
    , TableName VARCHAR(MAX)
    , ColumnName VARCHAR(MAX)
    , IsEncryptColumn BIT
    , IsSourceColumn BIT
    , IsIdentity BIT
)

--整理TableInfo
INSERT INTO @Tables(TableIndex, TableName, ColumnName)
SELECT DENSE_RANK() OVER(ORDER BY TABLE_NAME)
, A.TABLE_NAME, A.COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS A

--找到有EN_的欄位
UPDATE @Tables SET IsEncryptColumn = 1 WHERE ColumnName LIKE 'EN_%'

--找到EN_對應的遮罩欄位
UPDATE A SET A.IsSourceColumn = 1
FROM @Tables A
WHERE EXISTS(
    SELECT 'x'
    FROM @Tables X
    WHERE X.IsEncryptColumn = 1
        AND A.TableName = X.TableName
        AND A.ColumnName = RIGHT(X.ColumnName, LEN(X.ColumnName) - 3)
)

--找到設有Identity的欄位
UPDATE A SET IsIdentity = 1 FROM @Tables A WHERE EXISTS(
    SELECT 'x'
    FROM sys.columns c
    JOIN sys.tables t
        ON c.object_id = t.object_id
    WHERE t.name = A.TableName
        AND c.name = A.ColumnName
        AND c.is_identity = 1
)

--幾個Table
SELECT @TotalTables = MAX(TableIndex) FROM @Tables

WHILE @Count <= @TotalTables
BEGIN  
    --設定Table名稱
    SELECT @TableName = TableName FROM @Tables WHERE TableIndex = @Count GROUP BY TableName

    SET @Count = @Count + 1

    --如果Table沒有加密欄位則不做事
    IF((SELECT COUNT(IsEncryptColumn) FROM @Tables GROUP BY TableName HAVING TableName = @TableName) = 0) 
        CONTINUE

    DECLARE @Columns VARCHAR(MAX) = ''
    DECLARE @ColumnSource VARCHAR(MAX) = ''

    --取得Table INSERT欄位
    SELECT @Columns = @Columns + ColumnName + '@rn@     , ' 
    FROM @Tables 
    WHERE TableName = @TableName 
        AND ISNULL(IsIdentity, 0) <> 1
    ORDER BY ColumnName

    --處理字串尾部逗號
    SET @Columns = LEFT(@Columns, LEN(@Columns) - 1)

    --取得Table INSERT欄位的來源
    SELECT @ColumnSource = @ColumnSource + 
                                                        --原始Table都壓成XXX來遮罩資料
        CASE WHEN IsSourceColumn = 1 THEN ColumnName + ' = ''XXX'''                                               --去掉EN_才是原始原始資料
            WHEN IsEncryptColumn = 1 THEN ColumnName + ' = ENCRYPTBYKEY(@KeyGUID, CONVERT(VARBINARY(MAX), INS.' + RIGHT(ColumnName, LEN(ColumnName) - 3) + '))' 
            ELSE 'INS.' + ColumnName END
        + '@rn@     , ' 
    FROM @Tables 
    WHERE TableName = @TableName 
        AND ISNULL(IsIdentity, 0) <> 1
    ORDER BY ColumnName

    SET @ColumnSource = LEFT(@ColumnSource, LEN(@ColumnSource) - 1)
    

    SET @SQL = @Divider + '
CREATE TRIGGER TRGI_@TableName@
ON @TableName@
INSTEAD OF INSERT
AS
BEGIN

    OPEN SYMMETRIC KEY @SYMMETRIC_KEY_NAME@
    DECRYPTION BY CERTIFICATE @CERTIFICATE_NAME@
    WITH PASSWORD = ''@CertPass@''


    --取得金鑰名稱
    DECLARE @Name VARCHAR(250)
    SELECT @Name = @SYMMETRIC_KEY_NAME@
    DECLARE @KeyGUID AS UNIQUEIDENTIFIER
    SELECT @KeyGUID = KEY_GUID(@Name)

    INSERT INTO @TableName@ (@Columns@)@rn@    SELECT @ColumnSource@@rn@FROM INSERTED INS 
END@rn@'

    SET @SQL = REPLACE(@SQL, '@TableName@', @TableName)
    SET @SQL = REPLACE(@SQL, '@Columns@', @Columns)
    SET @SQL = REPLACE(@SQL, '@ColumnSource@', @ColumnSource)
    SET @SQL = REPLACE(@SQL, '@CertPass@', **************@CertPass@**************)
    SET @SQL = REPLACE(@SQL, '@SYMMETRIC_KEY_NAME@', **************@CertPass@**************)
    SET @SQL = REPLACE(@SQL, '@CERTIFICATE_NAME@', **************@CertPass@**************)

    SET @SQL = @SQL + @Divider

    SET @SQL = REPLACE(@SQL, '@rn@', CHAR(13) + CHAR(10))
    PRINT (@SQL)
    EXEC (@SQL)
END

--此語法會自動找到Table中有欄位為EN_XXX來產生INSERT TRIGGER
--之後INSERT進有EN_XXX欄位的Table就會自動用憑證加密內容存進EN_XXX並將值用假資料存進XXX欄位
--注意:每個EN_XXX都要建立對應的XXX欄位