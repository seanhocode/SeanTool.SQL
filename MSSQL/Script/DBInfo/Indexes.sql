--=========================索引與約束類=========================
IF(1 = 0)
--資料庫中的所有索引
SELECT object_id                    --索引所屬資料表的ID
    , name                          --索引名稱
    , index_id                      --索引ID(每個表從1開始)
    , type_desc                     --索引類型說明(例如CLUSTERED或NONCLUSTERED)
    , is_unique                     --是否為唯一索引
    , is_primary_key                --是否為主鍵索引
    , is_unique_constraint          --是否為唯一性約束
    , fill_factor                   --填充因子(0表示使用預設)
FROM sys.indexes

IF(1 = 0)
--索引對應的欄位
SELECT object_id                    --資料表ID
    , index_id                      --索引ID
    , column_id                     --欄位ID
    , key_ordinal                   --欄位在索引中的順序
    , is_descending_key             --是否為遞減排序
    , is_included_column            --是否為包含欄位(INCLUDE)
FROM sys.index_columns

IF(1 = 0)
--外鍵約束資訊
SELECT name                         --外鍵名稱
    , object_id                     --外鍵物件ID
    , parent_object_id              --父資料表ID
    , referenced_object_id          --被參照的資料表ID
    , delete_referential_action_desc--刪除時的參照行為描述
    , update_referential_action_desc--更新時的參照行為描述
FROM sys.foreign_keys

IF(1 = 0)
--檢查約束(Check Constraint)
SELECT name                         --約束名稱
    , object_id                     --約束物件ID
    , parent_object_id              --所屬資料表ID
    , definition                    --檢查條件定義
    , is_disabled                   --是否停用(1=是)
    , is_not_for_replication        --是否不套用於複寫(1=是)
FROM sys.check_constraints

IF(1 = 0)
--預設值約束(Default Constraint)
SELECT name                         --預設值約束名稱
    , object_id                     --約束物件ID
    , parent_object_id              --所屬資料表ID
    , definition                    --預設值定義
    , is_system_named               --是否為系統自動命名
FROM sys.default_constraints

IF(1 = 0)
--主鍵與唯一鍵約束
SELECT name                         --約束名稱
    , object_id                     --約束物件ID
    , parent_object_id              --所屬資料表ID
    , type_desc                     --約束類型說明(例如PRIMARY_KEY_CONSTRAINT, UNIQUE_CONSTRAINT)
    , is_system_named               --是否為系統自動命名
FROM sys.key_constraints

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_helpindex: 快速列出某張表身上所有的索引及其包含的欄位
    EXEC sp_helpindex 'YourTableName';

    -- sp_helpconstraint: 快速列出某張表身上所有的約束(PK, FK, Check, Default)
    EXEC sp_helpconstraint 'YourTableName';
END