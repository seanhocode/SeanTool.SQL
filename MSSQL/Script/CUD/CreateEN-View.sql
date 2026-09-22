DECLARE @SQL NVARCHAR(MAX)
DECLARE @TableName NVARCHAR(MAX)
DECLARE @Count BIGINT = 1
DECLARE @Divider VARCHAR(102) = '--===================================================================================================='
DECLARE @TotalTables BIGINT = 0
DECLARE @Tables TABLE(
    TableIndex BIGINT
    , TableName VARCHAR(MAX)
    , ColumnName VARCHAR(MAX)
    , ColumnSort INT
    , IsEncryptColumn BIT
    , IsSourceColumn BIT
)

--整理TableInfo
INSERT INTO @Tables(TableIndex, TableName, ColumnName, ColumnSort)
SELECT DENSE_RANK() OVER(ORDER BY TABLE_NAME)
, A.TABLE_NAME, A.COLUMN_NAME, A.ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS A

UPDATE @Tables SET IsEncryptColumn = 1 WHERE ColumnName LIKE 'EN_%'

UPDATE A SET A.IsSourceColumn = 1
FROM @Tables A
WHERE EXISTS(
    SELECT 'x'
    FROM @Tables X
    WHERE X.IsEncryptColumn = 1
        AND A.TableName = X.TableName
        AND A.ColumnName = RIGHT(X.ColumnName, LEN(X.ColumnName) - 3)
)

--幾個Table
SELECT @TotalTables = MAX(TableIndex) FROM @Tables

WHILE @Count <= @TotalTables
BEGIN
    SELECT @TableName = TableName FROM @Tables WHERE TableIndex = @Count GROUP BY TableName

    SET @Count = @Count + 1

    IF((SELECT COUNT(IsEncryptColumn) FROM @Tables GROUP BY TableName HAVING TableName = @TableName) = 0) 
        CONTINUE

    DECLARE @Columns NVARCHAR(MAX) = ''

    SELECT @Columns = @Columns + 
        CASE WHEN IsSourceColumn = 1 THEN 'CONVERT(VARCHAR,DecryptByKey(EN_' + ColumnName + ')) AS ' + ColumnName
        ELSE ColumnName END
        + '@rn@, '
    FROM @Tables WHERE TableName = @TableName AND ISNULL(IsEncryptColumn, 0) <> 1
    ORDER BY ColumnSort

    SET @Columns = LEFT(@Columns, LEN(@Columns) - 1)

    SET @SQL = @Divider + '
CREATE VIEW [dbo].[vwEN_@TableName@]
AS
    SELECT @Columns@ FROM @TableName@
'
    SET @SQL = REPLACE(@SQL, '@TableName@', @TableName)
    SET @SQL = REPLACE(@SQL, '@Columns@', @Columns)
    SET @SQL = @SQL + @Divider
    SET @SQL = REPLACE(@SQL, '@rn@', CHAR(13) + CHAR(10))

    PRINT (@SQL)
    EXEC (@SQL)
END