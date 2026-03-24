--=====================================================說明=====================================================
/*
遞迴 CTE 的語法包含 兩個部分：
    基礎查詢（Anchor Member）： 定義遞迴的起點
    遞迴成員（Recursive Member）： 透過 UNION ALL 來從上一輪結果推導新資料，並持續遞迴直到沒有新的資料可加入

    WITH RecursiveCTE AS (
        -- 基礎查詢 (起點)
        SELECT 初始資料
        FROM 資料表
        WHERE 條件

        UNION ALL

        -- 遞迴查詢 (連接上一次結果)
        -- 這裡的RecursiveCTE僅是上一輪執行結果
        SELECT 其他資料
        FROM 資料表
        JOIN RecursiveCTE ON 關聯條件
    )
    --這裡的RecursiveCTE包含所有層級的累積結果
    SELECT * FROM RecursiveCTE;
*/
--=====================================================說明=====================================================

--=====================================================範例=====================================================
CREATE TABLE #Employee (
    EmployeeID INT PRIMARY KEY,
    Name NVARCHAR(50),
    ManagerID INT NULL,
    FOREIGN KEY (ManagerID) REFERENCES #Employee(EmployeeID)
)


INSERT INTO #Employee (EmployeeID, Name, ManagerID) VALUES
-- CEO (最高層)
(1, 'Alice (CEO)', NULL),
-- 部門主管 (直接匯報給 CEO)
(2, 'Bob (CTO)', 1),
(3, 'Carol (CFO)', 1),
(4, 'David (COO)', 1),
-- 部門主管的下屬
(5, 'Eve (Dev Manager)', 2),
(6, 'Frank (QA Manager)', 2),
(7, 'Grace (Finance Manager)', 3),
(8, 'Heidi (Ops Manager)', 4),
-- 一般員工
(9, 'Ivan (Developer)', 5),
(10, 'Judy (Developer)', 5),
(11, 'Mallory (QA Engineer)', 6),
(12, 'Niaj (QA Engineer)', 6),
(13, 'Oscar (Accountant)', 7),
(14, 'Peggy (Ops Specialist)', 8)


;WITH EmployeeHierarchy AS (
    -- 基礎層級：選擇 CEO
    SELECT EmployeeID, Name, ManagerID, 1 AS Level
    FROM #Employee
    WHERE ManagerID IS NULL
    
    UNION ALL
    
    -- 遞迴查找下屬
    SELECT e.EmployeeID, e.Name, e.ManagerID, eh.Level + 1
    FROM #Employee e
    JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID
)
SELECT * FROM EmployeeHierarchy ORDER BY Level, EmployeeID

DROP TABLE #Employee
--=====================================================範例=====================================================