--=========================儲存與檔案類=========================
IF(1 = 0)
--伺服器上所有資料庫資訊
SELECT name                         --資料庫名稱
    , database_id                   --資料庫ID
    , owner_sid                     --擁有者SID
    , create_date                   --建立日期
    , compatibility_level           --相容性等級
    , collation_name                --定序名稱
    , state_desc                    --狀態說明(例如ONLINE, RESTORING, RECOVERING)
    , recovery_model_desc           --復原模式(例如FULL, SIMPLE, BULK_LOGGED)
    , containment_desc              --包含性模式(例如NONE, PARTIAL)
FROM sys.databases

IF(1 = 0)
--資料庫中的所有資料檔案
SELECT file_id                      --檔案ID
    , name                          --檔案邏輯名稱
    , physical_name                 --檔案實體路徑
    , type_desc                     --檔案類型(ROWS或LOG)
    , size                          --檔案大小(8KB為單位)
    , max_size                      --最大大小(-1表示無限制)
    , growth                        --成長設定(單位8KB或%)
FROM sys.database_files

IF(1 = 0)
--資料庫的檔案群組
SELECT data_space_id                --資料空間ID
    , name                          --檔案群組名稱
    , type_desc                     --類型說明(例如ROWS_FILEGROUP)
    , is_default                    --是否為預設群組
    , is_read_only                  --是否唯讀
FROM sys.filegroups

IF(1 = 0)
--所有資料庫檔案(伺服器層級，跨所有資料庫)
SELECT database_id                  --資料庫ID
    , file_id                       --檔案ID
    , name                          --檔案邏輯名稱
    , physical_name                 --實體檔案路徑
    , type_desc                     --檔案類型(ROWS或LOG)
    , size                          --檔案大小(8KB為單位)
    , max_size                      --最大大小(-1表示無限制)
    , growth                        --成長設定(8KB或百分比)
FROM sys.master_files

IF(1 = 1)
--磁碟空間詳細分配 (Storage Detail)：統計每張表佔用的空間與行數
SELECT 
    s.name AS [SchemaName]		  --Schema名稱
    , t.name AS [TableName]           --資料表名稱
    , p.rows AS [RowCount]          --總行數
    , SUM(a.total_pages) * 8 AS [TotalSpace(KB)] --總佔用空間
    , SUM(a.used_pages) * 8 AS [UsedSpace(KB)]  --實際已使用空間
    , (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS [UnusedSpace(KB)] --剩餘未使用空間
    , CAST(ROUND(SUM(CASE WHEN i.index_id <= 1 THEN a.total_pages ELSE 0 END) * 8 / 1024.0, 2) AS NUMERIC(36, 2)) AS DataMB
    , CAST(ROUND(SUM(CASE WHEN i.index_id > 1 THEN a.total_pages ELSE 0 END) * 8 / 1024.0, 2) AS NUMERIC(36, 2)) AS IndexMB
    , CAST(ROUND(SUM(a.total_pages) * 8 / 1024.0, 2) AS NUMERIC(36, 2)) AS TotalMB
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.is_ms_shipped = 0 AND i.type <= 1 --僅計算 User Table 的資料與聚集索引
GROUP BY s.name, t.name, p.rows
ORDER BY SUM(a.total_pages) DESC

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_spaceused: 快速顯示特定資料表或整個資料庫的佔用空間與行數
    EXEC sp_spaceused 'YourTableName';
    
    -- DB_NAME() & DB_ID(): 快速轉換資料庫的 ID 與名稱
    SELECT DB_NAME(1) AS SystemDBName, DB_ID('master') AS SystemDBID;
END