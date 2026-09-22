/*
    傳回小於或等於指定數值運算式的最大整數

    語法:FLOOR([傳入值])
*/
SELECT 'FLOOR(123.45)' AS 'SQL', FLOOR(123.45) AS 'Result'
UNION ALL SELECT 'FLOOR(-123.45)', FLOOR(-123.45)