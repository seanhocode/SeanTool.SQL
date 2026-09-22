/*
    傳回大於或等於指定數值運算式的最小整數

    語法:CEILING([傳入值])
*/
SELECT 'CEILING(123.45)' AS 'SQL', CEILING(123.45) AS 'Result'
UNION ALL SELECT 'CEILING(-123.45)', CEILING(-123.45)