DROP PROCEDURE [dbo].[spGetDataDiff]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE    	PROCEDURE  [dbo].[spGetDataDiff]
/*
-- =============================================
-- Create date: <yyyy.mm.dd>
-- Description:
    ParameterDesc:
        @KeyColumns
            可指定主鍵欄位，若未指定則自動帶入 PK 欄位，自動帶入PK時若兩邊PK欄位不同則會同時帶入兩邊的PK欄位
            
        @IgnoreColumns
            只可忽略非Key欄位

        @ColumnMapping
            對應不同欄位名稱，多對應用,分隔
            兩邊皆對應的到欄位才會納入比對，若有指定但找不到欄位則忽略該欄位
            格式：[DS1欄位名稱]:[DS2欄位名稱],[DS1欄位名稱]:[DS2欄位名稱]

        @IsWarningNotExist
            是否要顯示只存在於其中一個資料來源的欄位

-- Ex.
        SELECT * INTO SystemRepository_ST FROM SystemRepository
        
        UPDATE SystemRepository_ST SET [Value] = 'Test' WHERE [Value] = 'MTQ'
        ALTER TABLE SystemRepository_ST 
        ADD NewCol VARCHAR(20) NOT NULL DEFAULT 'Test'
        
        DELETE FROM SystemRepository_ST

        EXEC dbo.spGetDataDiff
            @DataSource1 = 'SystemRepository',
            @DataSource2 = 'SystemRepository_ST',
            @KeyColumns = NULL,
            @IgnoreColumns = NULL,
            @ColumnMapping = NULL,
            @IsWarningNotExist = 0

        DROP TABLE SystemRepository_ST
-- =============================================
*/
    @DataSource1            VARCHAR (MAX)
    , @DataSource2          VARCHAR (MAX)
    , @KeyColumns           VARCHAR (MAX)
    , @IgnoreColumns        VARCHAR (MAX)
    , @ColumnMapping        VARCHAR (MAX)
    , @IsWarningNotExist    BIT = 1
AS
BEGIN
    DECLARE @ColumnInfo         TABLE
    (
        DS1ColName      VARCHAR (MAX)
        , DS2ColName    VARCHAR (MAX)
        , IsKey         BIT DEFAULT 0
    )
    DECLARE @KeyConditionSQL    VARCHAR (MAX) = ''
    DECLARE @ColumnDiffSQL      VARCHAR (MAX) = ''
    DECLARE @CompareSQL         VARCHAR (MAX) = 
'
SELECT [KeyColumns]
    , Diff.ColName AS [DiffColumn]
    , Diff.DS1Value AS [DataSource1]_Value
    , Diff.DS2Value AS [DataSource2]_Value
FROM [DataSource1] DS1
FULL OUTER JOIN [DataSource2] DS2
    ON [KeyConditionSQL]
CROSS APPLY(
    [ColumnDiffSQL]
) AS Diff (ColName, DS1Value, DS2Value)
'

    --#region 處理 Key Columns
    --========================================取的欄位資訊========================================
    -- 加入對應欄位
    INSERT INTO @ColumnInfo (DS1ColName, DS2ColName)
    SELECT
        LEFT(C.Item, C.Pos - 1) AS Col1
        , SUBSTRING(C.Item, C.Pos + 1, LEN(C.Item)) AS Col2
    FROM (
        SELECT 
            [value] AS Item, 
            CHARINDEX(':', [value]) AS Pos
        FROM string_split(@ColumnMapping, ',')
    ) AS C
    WHERE C.Pos > 0 -- 有冒號才處理
        -- 確認兩邊欄位都存在
        AND EXISTS( 
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS X
            WHERE X.TABLE_NAME = @DataSource1
                AND X.COLUMN_NAME = LEFT(C.Item, C.Pos - 1)
        )
        AND EXISTS(
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS Y
            WHERE Y.TABLE_NAME = @DataSource2
                AND Y.COLUMN_NAME = SUBSTRING(C.Item, C.Pos + 1, LEN(C.Item))
        )

    -- 加入相同欄位
    INSERT INTO @ColumnInfo (DS1ColName, DS2ColName)
    SELECT DISTINCT C.COLUMN_NAME, C.COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS C
    WHERE C.TABLE_NAME = @DataSource1
        AND EXISTS(
            SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS X
            WHERE X.TABLE_NAME = @DataSource2
                AND X.COLUMN_NAME = C.COLUMN_NAME
        )

    -- 加入只存在於其中一個資料來源的欄位
    IF(@IsWarningNotExist = 1)
    BEGIN
        INSERT INTO @ColumnInfo (DS1ColName, DS2ColName)
        SELECT C.COLUMN_NAME, NULL
        FROM INFORMATION_SCHEMA.COLUMNS C
        WHERE C.TABLE_NAME = @DataSource1
            AND NOT EXISTS(
                SELECT 1
                FROM @ColumnInfo CI
                WHERE C.COLUMN_NAME = CI.DS1ColName
            )

        INSERT INTO @ColumnInfo (DS1ColName, DS2ColName)
        SELECT NULL, C.COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS C
        WHERE C.TABLE_NAME = @DataSource2
            AND NOT EXISTS(
                SELECT 1
                FROM @ColumnInfo CI
                WHERE C.COLUMN_NAME = CI.DS2ColName
            )
    END

    -- 標記 Key 欄位
    UPDATE CI
    SET IsKey = 1
    FROM @ColumnInfo CI
    WHERE CI.DS1ColName IS NOT NULL
        AND CI.DS2ColName IS NOT NULL
        AND EXISTS(
            SELECT 1
            FROM string_split(@KeyColumns, ',') X
            WHERE CI.DS1ColName = X.[value]
                OR CI.DS2ColName = X.[value]
        )

    -- 若沒有指定 Key 欄位，則自動帶入 PK 欄位
    IF NOT EXISTS(SELECT 1 FROM @ColumnInfo WHERE IsKey = 1)
    BEGIN
        UPDATE CI
        SET IsKey = 1
        FROM @ColumnInfo CI
        WHERE CI.DS1ColName IS NOT NULL
            AND CI.DS2ColName IS NOT NULL
            AND EXISTS(
                SELECT 1
                FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
                JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CU 
                    ON TC.CONSTRAINT_NAME = CU.CONSTRAINT_NAME
                WHERE TC.TABLE_NAME = @DataSource1
                    AND TC.CONSTRAINT_TYPE = 'PRIMARY KEY'
                    AND CI.DS1ColName = CU.COLUMN_NAME
            )

        UPDATE CI
        SET IsKey = 1
        FROM @ColumnInfo CI
        WHERE CI.DS1ColName IS NOT NULL
            AND CI.DS2ColName IS NOT NULL
            AND EXISTS(
                SELECT 1
                FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
                JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CU 
                    ON TC.CONSTRAINT_NAME = CU.CONSTRAINT_NAME
                WHERE TC.TABLE_NAME = @DataSource2
                    AND TC.CONSTRAINT_TYPE = 'PRIMARY KEY'
                    AND CI.DS2ColName = CU.COLUMN_NAME
            )
    END

    -- 移除忽略欄位
    DELETE CI
    FROM @ColumnInfo CI
    WHERE CI.IsKey = 0
        AND EXISTS(
            SELECT 1
            FROM string_split(@IgnoreColumns, ',') X
            WHERE CI.DS1ColName = X.[value]
                OR CI.DS2ColName = X.[value]
        )
    --========================================取的欄位資訊========================================
    
    --#endregion 處理 Key Columns
    IF NOT EXISTS(SELECT 1 FROM @ColumnInfo WHERE DS1ColName IS NOT NULL AND DS2ColName IS NOT NULL)
    BEGIN
        SELECT 'Error: No matching columns found between the two data sources.' AS ErrorMessage
        RETURN
    END
    IF NOT EXISTS(SELECT 1 FROM @ColumnInfo WHERE IsKey = 1)
    BEGIN
        SELECT 'Error: No key columns found.' AS ErrorMessage
        RETURN
    END
    
    --#region 組出腳本語法
    --========================================組出腳本語法========================================
    SELECT @KeyConditionSQL = @KeyConditionSQL
        + '    AND DS1.' + DS1ColName + ' = DS2.' + DS2ColName
        + CHAR (13) + CHAR (10)
    FROM @ColumnInfo
    WHERE IsKey = 1
    SET @KeyConditionSQL = STUFF(@KeyConditionSQL, 1, 8, '')

    SELECT @ColumnDiffSQL = @ColumnDiffSQL
        + CHAR (13) + CHAR (10) + '    '
        + 'UNION SELECT ''' + ISNULL(CI.DS1ColName, CI.DS2ColName) + ''''
        + CASE WHEN CI.DS1ColName IS NOT NULL THEN ', CAST(DS1.' + CI.DS1ColName + ' AS NVARCHAR(MAX))' ELSE ', NULL' END
        + CASE WHEN CI.DS2ColName IS NOT NULL THEN ', CAST(DS2.' + CI.DS2ColName + ' AS NVARCHAR(MAX))' ELSE ', NULL' END
        + CASE 
            WHEN (CI.DS1ColName IS NOT NULL AND CI.DS2ColName IS NOT NULL)
                THEN ' WHERE EXISTS (SELECT DS1.' + CI.DS1ColName + ' EXCEPT SELECT DS2.' + CI.DS2ColName + ')'
            ELSE ''
        END
    FROM @ColumnInfo CI
    WHERE IsKey = 0
    
    -- 在最後補上一個「整列是否存在」的判斷
    SET @ColumnDiffSQL = @ColumnDiffSQL 
        + CHAR(13) + CHAR(10) + '    UNION ALL SELECT ''_ROW_STATUS'''
        + ', CASE WHEN DS1.' + (SELECT TOP 1 DS1ColName FROM @ColumnInfo WHERE IsKey = 1) + ' IS NULL THEN ''Missing'' ELSE ''Exists'' END'
        + ', CASE WHEN DS2.' + (SELECT TOP 1 DS2ColName FROM @ColumnInfo WHERE IsKey = 1) + ' IS NULL THEN ''Missing'' ELSE ''Exists'' END'
        + ' WHERE DS1.' + (SELECT TOP 1 DS1ColName FROM @ColumnInfo WHERE IsKey = 1) + ' IS NULL OR DS2.' + (SELECT TOP 1 DS1ColName FROM @ColumnInfo WHERE IsKey = 1) + ' IS NULL'
        
    SET @ColumnDiffSQL = STUFF(@ColumnDiffSQL, 1, 12, '')

    SET @CompareSQL = REPLACE(@CompareSQL, '[DataSource1]', @DataSource1)
    SET @CompareSQL = REPLACE(@CompareSQL, '[DataSource2]', @DataSource2)
    SET @CompareSQL = REPLACE(@CompareSQL, '[ColumnDiffSQL]', @ColumnDiffSQL)
    SET @CompareSQL = REPLACE(@CompareSQL, '[KeyConditionSQL]', @KeyConditionSQL)
    SET @CompareSQL = REPLACE(@CompareSQL, '[KeyColumns]', (SELECT STRING_AGG('COALESCE(DS1.' + DS1ColName + ', DS2.' + DS2ColName + ') AS ' + DS1ColName, ', ') FROM @ColumnInfo WHERE IsKey = 1))
    -- SET @CompareSQL = REPLACE(
    --         @CompareSQL
    --         , '[KeyColumns]'
    --         , (
    --             SELECT STRING_AGG('''' + T.DS1ColName + '='' + CAST(DS1.' + T.DS1ColName + ' AS VARCHAR) + '',''', ' + ') 
    --             FROM (SELECT DISTINCT DS1ColName FROM @ColumnInfo WHERE IsKey = 1) T
    --         )
    --     )
    --========================================組出腳本語法========================================
    --#endregion 組出腳本語法

    EXEC(@CompareSQL)
    PRINT @CompareSQL
END