--=========================進階維運與調校類=======================
IF(1 = 0)
--遺失索引 (Missing Indexes)：找出 SQL Server 建議建立但尚未建立的索引
SELECT 
    gs.user_seeks * gs.avg_total_user_cost * (gs.avg_user_impact / 100.0) AS [ExpectedImprovement] --預期提升效益
    , gs.last_user_seek                                         --最後一次參考此索引的查詢時間
    , db_name(d.database_id) AS [DatabaseName]                  --資料庫名稱
    , object_name(d.object_id, d.database_id) AS [TableName]    --資料表名稱
    , d.equality_columns                                        --等號運算子常用欄位(=)
    , d.inequality_columns                                      --不等號運算子常用欄位(<, >, !=)
    , d.included_columns                                        --建議包含在 INCLUDE 中的欄位
FROM sys.dm_db_missing_index_groups g
JOIN sys.dm_db_missing_index_group_stats gs ON gs.group_handle = g.index_group_handle
JOIN sys.dm_db_missing_index_details d ON g.index_handle = d.index_handle

IF(1 = 0)
--資源鎖定與阻塞 (Locks & Blocking)：查看誰正在阻塞別人，以及被卡住的 SQL 內容
SELECT 
    r.session_id                            --被阻塞的會話 ID
    , r.blocking_session_id                 --阻塞來源的會話 ID (元兇)
    , r.wait_type                           --等待類型 (例如 LCK_M_X)
    , r.wait_time / 1000.0 AS [WaitTime(s)] --已等待秒數
    , st.text AS [BlockedQueryText]         --被卡住的 SQL 語句內容
    , s.program_name                        --發起請求的應用程式名稱
    , s.host_name                           --發起請求的主機名稱
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.blocking_session_id <> 0

IF(1 = 0)
--活躍中的交易 (Transactions)：追蹤開啟中且尚未 Commit/Rollback 的交易
SELECT 
    s.session_id                    --會話 ID
    , s.login_name                  --登入帳號
    , t.transaction_id              --交易 ID
    , t.name AS [TransactionName]   --交易名稱
    , t.transaction_begin_time      --交易開始時間
    , t.transaction_state           --交易狀態(2=Active, 3=Ended, 4=CommitStarted)
FROM sys.dm_tran_active_transactions t
JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id
JOIN sys.dm_exec_sessions s ON st.session_id = s.session_id

IF(1 = 0)
--等待統計：分析伺服器累積至今的主要效能瓶頸
SELECT TOP 10
    wait_type                           --等待類型
    , wait_time_ms / 1000.0 AS [WaitS]  --累積等待秒數
    , (100.0 * wait_time_ms) / SUM(wait_time_ms) OVER() AS [Percentage]
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK') --過濾掉系統常態睡眠
ORDER BY wait_time_ms DESC

IF(1 = 0)
--索引碎片率：檢查索引是否需要重組(Reorganize)或重建(Rebuild)
SELECT 
    object_name(ips.object_id) AS [TableName]
    , i.name AS [IndexName]
    , ips.avg_fragmentation_in_percent  --平均碎片百分比
    , ips.page_count                    --佔用的頁數
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10 --通常大於 10% 就要注意

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_updatestats: 針對當前資料庫執行所有統計資料更新 (效能低落時的常見解法)
    EXEC sp_updatestats;
    
    -- DB_ID(): 在呼叫 DMV (如索引碎片檢視) 時，常動態傳入當前資料庫的 ID 避免全伺服器掃描
    SELECT DB_ID();
END