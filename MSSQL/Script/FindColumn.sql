DECLARE @Value NVARCHAR(MAX) = '%SeanTest%'

--查詢Table所有欄位名稱
SELECT A.TABLE_NAME, A.COLUMN_NAME, A.DATA_TYPE, A.ORDINAL_POSITION, A.CHARACTER_MAXIMUM_LENGTH--, B.[value]
FROM INFORMATION_SCHEMA.COLUMNS A
WHERE A.COLUMN_NAME like @Value
ORDER BY TABLE_NAME

--查詢sp內容
SELECT 
    p.name AS ProcedureName,
    m.definition AS SqlDefinition
FROM sys.procedures p
JOIN sys.sql_modules m 
    ON p.object_id = m.object_id
WHERE m.definition LIKE @Value
ORDER BY p.name

--查詢UDF內容
SELECT 
    o.name AS FunctionName,
    m.definition AS SqlDefinition,
    o.type_desc AS FunctionType
FROM sys.objects o
JOIN sys.sql_modules m 
    ON o.object_id = m.object_id
WHERE o.type IN ('FN', 'IF', 'TF')  -- FN: Scalar, IF: Inline TVF, TF: Multi-statement TVF
    AND m.definition LIKE @Value
ORDER BY o.name

--查詢vw內容
SELECT 
    v.name AS ViewName,
    m.definition AS SqlDefinition
FROM sys.views v
JOIN sys.sql_modules m ON v.object_id = m.object_id
WHERE m.definition LIKE @Value
ORDER BY v.name