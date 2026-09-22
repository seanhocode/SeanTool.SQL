/*
========================================================================================
Description：
    查詢資料表中指定欄位是否存在特定值，並統計符合條件的資料筆數。
========================================================================================
*/

DECLARE @TargetColumn TABLE(
    ColumnName NVARCHAR(128)
)

INSERT INTO @TargetColumn (ColumnName)          --目標欄位
VALUES ('PartyRoleID'),
        ('PER_SERIL_NO')
DECLARE @TargetValue NVARCHAR(MAX) = '10607888' --目標值

CREATE TABLE #CheckTable(
    TableName   NVARCHAR(128),
    ColumnName  NVARCHAR(128),
    DataType    NVARCHAR(128),
    DataCount   BIGINT DEFAULT 0
)

INSERT INTO #CheckTable (TableName, ColumnName, DataType)
SELECT 
    C.TABLE_NAME, C.COLUMN_NAME, C.DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS C
JOIN INFORMATION_SCHEMA.TABLES T 
    ON C.TABLE_SCHEMA = T.TABLE_SCHEMA 
    AND C.TABLE_NAME = T.TABLE_NAME
WHERE T.TABLE_TYPE = 'BASE TABLE'
    AND EXISTS(
    SELECT 1
        FROM @TargetColumn x
        WHERE C.COLUMN_NAME = x.ColumnName
    )

DECLARE @TableName  NVARCHAR(128),
        @ColumnName NVARCHAR(128),
        @DataType   NVARCHAR(128),
        @SQL        NVARCHAR(MAX)

DECLARE TableCursor CURSOR FOR
SELECT TableName, ColumnName, DataType
FROM #CheckTable
ORDER BY ColumnName, TableName

OPEN TableCursor
FETCH NEXT FROM TableCursor INTO @TableName, @ColumnName, @DataType

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT(@TableName)
    SET @SQL = N'
UPDATE #CheckTable 
SET DataCount = (SELECT COUNT(1) FROM [@TableName] WHERE [@ColumnName] = ''@TargetValue'')
WHERE TableName = ''@TableName'' 
    AND ColumnName = ''@ColumnName'' 
    AND DataType = ''@DataType'''
    
    SET @SQL = REPLACE(@SQL, '@TableName', @TableName)
    SET @SQL = REPLACE(@SQL, '@ColumnName', @ColumnName)
    SET @SQL = REPLACE(@SQL, '@DataType', @DataType)
    SET @SQL = REPLACE(@SQL, '@TargetValue', @TargetValue)

    EXEC sp_executesql @SQL

    FETCH NEXT FROM TableCursor INTO @TableName, @ColumnName, @DataType
END

SELECT *
FROM #CheckTable
WHERE DataCount > 0
ORDER BY ColumnName, TableName

CLOSE TableCursor
DEALLOCATE TableCursor
DROP TABLE #CheckTable