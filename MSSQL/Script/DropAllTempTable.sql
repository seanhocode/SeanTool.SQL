DECLARE @SQL NVARCHAR(MAX) = ''

SELECT @SQL = @SQL + N'DROP TABLE ' + QUOTENAME(LEFT(name, CHARINDEX('___', name) - 1)) + N'; '
FROM tempdb.sys.tables
WHERE name LIKE '#%'
	AND CHARINDEX('___', name) > 0
	AND OBJECT_ID('tempdb..' + name) IS NOT NULL

EXEC sp_executesql @SQL