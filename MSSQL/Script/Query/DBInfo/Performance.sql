--=========================效能與監控類 (DMV)=========================
IF(1 = 0)
--目前執行中的請求(查詢或批次)
SELECT R.session_id                 --會話ID
    , R.request_id                  --請求ID(同一session內唯一)
    , R.status                      --目前狀態(例如running, suspended)
    , R.command                     --正在執行的命令
    , R.database_id                 --目標資料庫ID
    , R.blocking_session_id         --阻塞來源的session ID
    , R.wait_type                   --等待類型
    , R.wait_time                   --等待時間(毫秒)
    , R.cpu_time                    --CPU使用時間(毫秒)
    , R.total_elapsed_time          --總執行時間(毫秒)
    , ST.text AS [SQL_Full_Text]    --SQL語法
FROM sys.dm_exec_requests R
CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) ST

IF(1 = 0)
--目前的連線會話(Session)
SELECT session_id                   --會話ID
    , login_name                    --登入使用者名稱
    , host_name                     --主機名稱
    , program_name                  --應用程式名稱
    , login_time                    --登入時間
    , last_request_start_time       --最後請求開始時間
    , last_request_end_time         --最後請求結束時間
    , status                        --會話狀態(例如running, sleeping)
    , cpu_time                      --CPU使用時間(毫秒)
    , memory_usage                  --記憶體使用量(8KB為單位)
FROM sys.dm_exec_sessions

IF(1 = 1)
--查詢統計資訊(可用於分析效能)
SELECT S.sql_handle                 --查詢的SQL識別碼
    , S.execution_count             --執行次數
    , S.total_worker_time           --總CPU時間(微秒)
    , S.total_elapsed_time          --總執行時間(微秒)
    , S.total_logical_reads         --總邏輯讀取頁數
    , S.total_logical_writes        --總邏輯寫入頁數
    , S.creation_time               --快取建立時間
    , S.last_execution_time         --最後執行時間
    , ST.text                       --SQL語法
    , QP.query_plan                 --執行計畫圖
FROM sys.dm_exec_query_stats S
CROSS APPLY sys.dm_exec_sql_text(S.sql_handle) AS ST
--關聯 執行計畫 (選配，若不需要可註解掉以提升查詢速度)
CROSS APPLY sys.dm_exec_query_plan(S.plan_handle) AS QP
--依照 CPU 消耗量排序，抓出最吃資源的
ORDER BY S.total_worker_time DESC

IF(1 = 0)
--索引使用統計(分析索引效能與利用率)
SELECT database_id                  --資料庫ID
    , object_id                     --物件ID
    , index_id                      --索引ID
    , user_seeks                    --使用者查詢seek次數
    , user_scans                    --使用者查詢scan次數
    , user_lookups                  --使用者查詢lookup次數
    , user_updates                  --資料修改次數
    , last_user_seek                --最後seek時間
    , last_user_scan                --最後scan時間
    , last_user_lookup              --最後lookup時間
    , last_user_update              --最後更新時間
FROM sys.dm_db_index_usage_stats

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_who2: DBA 最常敲的指令，快速查看當前連線狀態、CPU 與 Disk IO
    EXEC sp_who2;
    
    -- sys.dm_exec_sql_text(): 搭配 CROSS APPLY，將 handle 轉回 SQL 語法 (以 session 為例)
    SELECT st.text FROM sys.dm_exec_requests r 
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st WHERE r.session_id > 50;

    -- sys.dm_exec_query_plan(): 取得執行計畫 XML
    -- SELECT qp.query_plan FROM sys.dm_exec_requests r 
    -- CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) qp;
END