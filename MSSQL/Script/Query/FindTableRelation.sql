DECLARE @TargetTable NVARCHAR(128) = 'UnpaidLeave'
DECLARE @TableRelations TABLE (
    TableName       NVARCHAR(128),  -- 原始表
    ChildTableName  NVARCHAR(128)   -- 子表(外鍵所在)
)

DECLARE @ParentDirection    NVARCHAR(50) = @TargetTable + '依賴的父表'
DECLARE @ChildDirection     NVARCHAR(50) = '依賴' + @TargetTable + '的子表'

INSERT INTO @TableRelations (TableName, ChildTableName)
SELECT KCU2.TABLE_NAME AS TableName, KCU1.TABLE_NAME AS ChildTableName  
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS RC
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU1 
    ON RC.CONSTRAINT_NAME = KCU1.CONSTRAINT_NAME
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU2 
    ON RC.UNIQUE_CONSTRAINT_NAME = KCU2.CONSTRAINT_NAME 
    AND KCU1.ORDINAL_POSITION = KCU2.ORDINAL_POSITION

-- 遞迴往上找：找出目標表參考了哪些表 (父表、祖父表...)
;WITH FindParents AS (
    -- 基準點：目標表的第一層父表
    SELECT TableName AS RelatedTable, 1 AS Level, @ParentDirection AS Direction
    FROM @TableRelations
    WHERE ChildTableName = @TargetTable
    
    UNION ALL
    
    SELECT f.TableName AS RelatedTable, p.Level + 1, @ParentDirection AS Direction
    FROM @TableRelations f
    INNER JOIN FindParents p ON f.ChildTableName = p.RelatedTable
),

-- 遞迴往下找：找出哪些表參考了目標表 (子表、孫表...)
FindChildren AS (
    -- 基準點：目標表的第一層子表
    SELECT ChildTableName AS RelatedTable, 1 AS Level, @ChildDirection AS Direction
    FROM @TableRelations
    WHERE TableName = @TargetTable
    
    UNION ALL
    
    SELECT f.ChildTableName AS RelatedTable, c.Level + 1, @ChildDirection AS Direction
    FROM @TableRelations f
    INNER JOIN FindChildren c ON f.TableName = c.RelatedTable
)

-- 將往上和往下的結果合併，並排除重複項目
SELECT 
    RelatedTable,   -- 相關表名稱
    Direction,      -- 依賴方向
    MIN(Level)      -- 相關表與目標表的層級距離
FROM (
    SELECT * FROM FindParents
    UNION ALL
    SELECT * FROM FindChildren
) AS AllRelations
GROUP BY RelatedTable, Direction
ORDER BY Direction DESC, MIN(Level) ASC