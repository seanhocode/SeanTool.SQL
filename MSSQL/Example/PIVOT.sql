/*
    翻轉Table
    彙總函數使用MAX可翻轉字串不彙總成數字

    語法:
    SELECT [GroupByColumn], [各個選項]
    FROM   
    (
        SELECT [來源Table的欄位]
        FROM [來源Table]
    ) p	   
    PIVOT  
    (  
        [要使用的彙總函數]([各個選項的值])
        FOR [各個選項的欄位] IN  
            ([各個選項])
    ) AS pvt  
*/
--=================================準備資料=================================
CREATE TABLE #Test(
    People VARCHAR(100),
    PeopleID INT,
    ItemName VARCHAR(100),
    Cost INT
)
CREATE TABLE #TestMAX(
    People VARCHAR(100),
    PeopleID INT,
    Item VARCHAR(100),
    [Value] INT
)
DECLARE @Items VARCHAR(MAX) = ''
DECLARE @Sql NVARCHAR(MAX) = ''
INSERT INTO #Test (People, PeopleID, ItemName, Cost)
SELECT 'Sean', 1, 'Phone', '100'
UNION SELECT 'Sean', 1, 'Computer', '200'
UNION SELECT 'Sean', 1, 'Car', '1000'
UNION SELECT 'Sean', 1, 'Phone', '50'
UNION SELECT 'John', 2, 'Car', '2000'
UNION SELECT 'John', 2, 'Phone', '50'
UNION SELECT 'John', 2, 'Car', '200'
UNION SELECT 'Wendy', 3, 'Clothes', '100'

INSERT INTO #TestMAX (People, PeopleID, Item, [Value])
SELECT 'Sean', 1, 'Email', 1
UNION SELECT 'Sean', 1, 'Phone', 1
UNION SELECT 'Sean', 1, 'Address', 1
UNION SELECT 'Sean', 1, 'Address', 5
UNION SELECT 'John', 2, 'Email', 1
UNION SELECT 'John', 2, 'Address', 1
UNION SELECT 'Wendy', 3, 'Phone', 1
--==========================================================================

SELECT * FROM #Test
SELECT * FROM #TestMAX

--=================================PIVOT====================================
SELECT People, PeopleID, [Car], [Phone], [Computer], [Clothes]
FROM   
(
    SELECT People, PeopleID, ItemName, Cost
    FROM #Test
) p	
PIVOT  
(  
    SUM(Cost)
    FOR ItemName IN  
        ([Car], [Phone], [Computer], [Clothes])
) AS pvt  
--==========================================================================

--=================================動態PIVOT=================================
SELECT @Items = @Items + '[' + ItemName + ']' FROM #Test GROUP BY ItemName
SET @Items = REPLACE(@Items, '][', '],[')

SET @Sql = N'
SELECT People, PeopleID, ' + @Items + N'
FROM   
(
    SELECT People, PeopleID, ItemName, Cost
    FROM #Test
) p	
PIVOT  
(  
    MAX(Cost)
    FOR ItemName IN  
        (' + @Items + N')
) AS pvt 
'

EXEC sp_executesql @Sql
--==========================================================================

--=================================動態PIVOT=================================
SET @Items = ''
SELECT @Items = @Items + '[' + Item + ']' FROM #TestMAX GROUP BY Item
SET @Items = REPLACE(@Items, '][', '],[')
SET @Sql = N'
SELECT People, PeopleID, ' + @Items + N'
FROM   
(
    SELECT People, PeopleID, Item, [Value]
    FROM #TestMAX
) p	
PIVOT  
(  
    MAX([Value])
    FOR Item IN  
        (' + @Items + N')
) AS pvt 
'

EXEC sp_executesql @Sql
--==========================================================================

    DROP TABLE #Test
    DROP TABLE #TestMAX