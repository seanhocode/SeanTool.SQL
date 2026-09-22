EXEC sp_who2;

--============================================================================================================
-- 【第一階段：緊急救火】系統當下正在卡頓、發生鎖定 (Blocking) 時，馬上抓出現行犯
--============================================================================================================

/*
    目的 : 查詢目前系統中發生鎖定 (Blocking) 的源頭，以及該 SPID 正在執行的 SQL 語法。
    結果 : 元兇 SPID、被誰阻擋 (0 代表自己是源頭)、等待時間、最後等待類型、資料庫名稱、登入帳號、應用程式名稱、連線狀態及最後執行的 SQL 語法。
    限制 : 只能查出「當下」還連線在系統上的 SPID。若對方已斷線，則無法透過此語法查到。
    權限 : 需要 VIEW SERVER STATE 權限 (SQL 2022+ 為 VIEW SERVER PERFORMANCE STATE)。
    時機 : 當下有人反應系統沒有回應、卡死，第一時間用來找出是哪個連線 (SPID) 鎖住大家。
*/
SELECT
    p.spid AS [元兇SPID],
    p.kpid AS [執行緒ID],
    p.blocked AS [它被誰擋(0代表它就是源頭)],
    p.waittime / 1000.0 AS [它自己等了幾秒],
    p.lastwaittype AS [最後等待類型],
    DB_NAME(p.dbid) AS [資料庫名稱],
    p.loginame AS [登入帳號],
    p.hostname AS [連線電腦名稱],
    p.program_name AS [應用程式名稱],
    p.status AS [連線狀態],
    t.text AS [元兇最後執行的SQL語法]
FROM sys.sysprocesses p
OUTER APPLY sys.dm_exec_sql_text(p.sql_handle) t
--WHERE p.spid = 55; -- 請在此輸入您要檢查的元兇 SPID

--============================================================================================================

/*
    目的 : 針對已抓到的特定 SPID，抓出它當下正在執行的「最源頭/完整」批次 SQL 語法。
    結果 : SPID、狀態、正在執行的指令類型、當下執行語句，以及完整整批 SQL 或預存程序內容。
    限制 : 僅限當下仍處於執行中 (Active/Running) 的連線。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 已經鎖定某個作亂的 SPID，想要進一步看它目前確切在跑哪一段批次或哪一行 Code 時。
*/
SELECT
    r.session_id,
    r.status,
    r.command,
    SUBSTRING(st.text, (r.statement_start_offset/2)+1,  
        ((CASE r.statement_end_offset  
          WHEN -1 THEN DATALENGTH(st.text) 
         ELSE r.statement_end_offset END - r.statement_start_offset)/2) + 1) AS [當下執行語句],
    st.text AS [完整整批SQL或預存程序內容]
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
--WHERE r.session_id = 55; -- 請替換成該 SPID

--============================================================================================================

/*
    目的 : 檢查特定的 SPID 是否包在一個「巨大的或未提交的 Transaction (交易)」裡面。
    結果 : Session ID 與未結束的交易數量。
    限制 : 只能反應當下的交易數量，無法得知該交易內包含多少筆資料異動。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 確認鎖定別人的 SPID 是否因為開啟了 BEGIN TRAN 卻遲遲沒有 COMMIT 導致鎖定資源。
*/
SELECT
    session_id,
    open_transaction_count AS [未結束的交易數量]
FROM sys.dm_exec_sessions
--WHERE session_id = 55; -- 請替換成該 SPID

--============================================================================================================

/*
    目的 : 找出已經閒置 (Sleeping) 但手上還握著交易未釋放的語法 (Sleeping with open transactions)。
    結果 : SPID、連線狀態、未結束交易數、登入帳號、電腦名稱、最後讀寫時間，以及最後執行的 SQL 語法內容。
    限制 : 該連線必須尚未斷開。如果是應用程式端未正確關閉連線或遺漏 COMMIT，才會出現此狀態。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 發現 Blocking 源頭的狀態是 Sleeping，想揪出到底是哪段程式碼沒寫 COMMIT/ROLLBACK 把資料庫卡死時。
*/
SELECT
    s.session_id AS [SPID],
    s.status AS [連線狀態],
    s.open_transaction_count AS [未結束交易數],
    s.login_name AS [登入帳號],
    s.host_name AS [電腦名稱],
    s.program_name AS [應用程式],
    c.last_read AS [最後讀取時間],
    c.last_write AS [最後寫入時間],
    st.text AS [最後執行的整批SQL語法内容]
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) st
WHERE s.status = 'sleeping' AND s.open_transaction_count > 0;
-- AND s.session_id = 193; -- 請替換成您的元凶 SPID

--============================================================================================================

/*
    目的 : 查詢特定 SPID 目前已經累積消耗了多少 CPU、邏輯讀取與實體寫入，評估其負載程度。
    結果 : 累計 CPU 時間、累計邏輯讀取、累計寫入量。
    限制 : 顯示的數值是該 Session "從連線建立至今" 的累積值，若有 Connection Pooling 重複使用，數值可能包含前次查詢。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 猶豫是否要將一個跑了很久的查詢 KILL 掉前，先評估它到底已經消耗了多少系統資源。
*/
SELECT
    session_id,
    status,
    cpu_time AS [累計CPU時間],
    logical_reads AS [累計邏輯讀取],
    writes AS [累計寫入]
FROM sys.dm_exec_sessions
--WHERE session_id = 193; -- 請替換成您的元凶 SPID


--============================================================================================================
-- 【第二階段：案發現場急救】系統剛剛飆高或卡死，且連線剛斷開 / 被 KILL 掉
--============================================================================================================

/*
    目的 : 緊急「驗屍」專用。快速從快取中挖出剛執行完 (或被強制 KILL 中斷) 且總邏輯讀取量極大的巨大查詢。
    結果 : 總執行次數、總邏輯讀取、總CPU時間(毫秒)、總花費時間(毫秒)、最後執行時間、擷取出的最操資源語法，以及完整的 SQL 內容。
    限制 : 極度依賴記憶體快取。如果該連線引發極大的記憶體壓力導致計畫快取立刻被置換，就會抓不到。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 案發現場急救！當肇事的連線已經自行斷開或被你強制終止 (KILL) 後，趁記憶體快取還沒被洗掉，趕快把它挖出來檢驗。
*/
SELECT TOP 10
    qs.execution_count AS [總執行次數],
    qs.total_logical_reads AS [總邏輯讀取],
    qs.total_worker_time / 1000.0 AS [總CPU時間(毫秒)],
    qs.total_elapsed_time / 1000.0 AS [總花費時間(毫秒)],
    qs.last_execution_time AS [最後執行時間],
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset 
          WHEN -1 THEN DATALENGTH(st.text) 
         ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS [最操資源的單句語法],
    st.text AS [完整SQL或預存程序內容]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.last_execution_time DESC, qs.total_logical_reads DESC; -- 依照時間與資源消耗排序

--============================================================================================================

/*
    目的 : 從預設的 system_health 擴充事件中，撈取過去 24 小時內發生的死鎖 (Deadlock) 或嚴重資源等待 (Wait Info)。
    結果 : 事件類型、UTC發生時間、等待類型、等待時間(毫秒)、當時執行的SQL、SPID(連線ID)，以及包含完整診斷資訊的 XML。
    限制 : 依賴循環寫入的 XEvent 檔案，若系統過忙，舊紀錄可能不到 24 小時就被覆蓋。紀錄的時間為 UTC，閱讀需自行加時差 (台灣 UTC+8)。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 事後還原卡頓發生原因。當開發人員反應程式拋出 Deadlock (Error 1205)，或昨天某時段系統出現大規模等待時使用。
*/
SELECT TOP 50
    object_name AS [事件類型],
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'datetime2') AS [UTC發生時間],
    CAST(event_data AS XML).value('(/event/data[@name="wait_type"]/text)[1]', 'varchar(50)') AS [等待類型],
    CAST(event_data AS XML).value('(/event/data[@name="duration"]/value)[1]', 'bigint') / 1000.0 AS [等待時間(毫秒)],
    CAST(event_data AS XML).value('(/event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [當時執行的SQL],
    CAST(event_data AS XML).value('(/event/action[@name="session_id"]/value)[1]', 'int') AS [SPID],
    CAST(event_data AS XML) AS [完整XML詳細資料]
FROM sys.fn_xe_file_target_read_file('system_health*.xel', null, null, null)
WHERE object_name IN ('wait_info', 'xml_deadlock_report')
  AND CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'datetime2') >= DATEADD(HOUR, -24, GETUTCDATE())
ORDER BY [UTC發生時間] DESC;


--============================================================================================================
-- 【第三階段：歷史效能追查】透過 Query Store 調閱特定歷史時段的效能瓶頸
--============================================================================================================

/*
    目的 : 查詢 SQL Server 的 Query Store 設定狀態。
    結果 : Query Store 的實際狀態 (如 READ_WRITE 或 READ_ONLY)、期望狀態以及唯讀原因。
    限制 : 僅適用於 SQL Server 2016 及更新版本。無法查閱過去何時發生過狀態切換。
    權限 : 需要 VIEW DATABASE STATE 權限。
    時機 : 準備進行歷史效能分析前，先確認 Query Store 是否正常運作，有無因磁碟空間不足自動變更為唯讀狀態。
*/
SELECT
    actual_state_desc,
    desired_state_desc,
    readonly_reason
FROM sys.database_query_store_options;

--============================================================================================================

/*
    目的 : 透過 Query Store 查詢「特定歷史時段內」(例如 08:00 到 12:00) 總邏輯讀取量最高的 SQL 語法。
    結果 : 查詢 ID、SQL 語法、執行次數、總花費時間(毫秒)、總 CPU 時間(毫秒)、總邏輯讀取與實體讀取量。
    限制 : 依賴 Query Store 正常啟用且資料未超過保留天數。
    權限 : 需要 VIEW DATABASE STATE 權限。
    時機 : 系統當下已恢復正常，你需要事後追查昨天晚上或早上尖峰時刻，整體 I/O 負載突然飆高的肇因。
*/
SELECT TOP 20
    q.query_id,
    qt.query_sql_text,
    SUM(rs.count_executions) AS exec_count,
    SUM(rs.avg_duration * rs.count_executions) / 1000.0 AS total_duration_ms,
    SUM(rs.avg_cpu_time * rs.count_executions) / 1000.0 AS total_cpu_ms,
    SUM(rs.avg_logical_io_reads * rs.count_executions) AS total_logical_reads,
    SUM(rs.avg_physical_io_reads * rs.count_executions) AS total_physical_reads
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval i ON rs.runtime_stats_interval_id = i.runtime_stats_interval_id
WHERE i.start_time >= '2026-09-01T08:00:00'
  AND i.end_time   <= '2026-09-01T12:00:00'
GROUP BY q.query_id, qt.query_sql_text
ORDER BY total_logical_reads DESC;

--============================================================================================================

/*
    目的 : 透過 Query Store 查詢「特定歷史時段內」平均單次執行時間 (Duration) 最慢的 SQL 語法。
    結果 : SQL 語法、平均執行時間、平均 CPU 時間、平均邏輯讀取、執行次數及統計時段。
    限制 : 執行時間長不代表一定耗費大量 CPU/IO，也可能是該時段處於鎖定等待 (Blocking) 狀態。受限於 QS 資料保留天數。
    權限 : 需要 VIEW DATABASE STATE 權限。
    時機 : 使用者抱怨在過去某個時段「某個功能按下去等很久」，用做事後調閱該時段單次執行最慢的語法。
*/
SELECT TOP 20
    qt.query_sql_text,
    rs.avg_duration,
    rs.avg_cpu_time,
    rs.avg_logical_io_reads,
    rs.count_executions,
    i.start_time,
    i.end_time
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval i ON rs.runtime_stats_interval_id = i.runtime_stats_interval_id
WHERE i.start_time >= '2026-09-01T08:00:00'
  AND i.end_time   <= '2026-09-01T12:00:00'
ORDER BY rs.avg_duration DESC;


--============================================================================================================
-- 【第四階段：日常維護與優化】從執行計畫快取找出資源怪獸進行重構或加索引
--============================================================================================================

/*
    目的 : 從執行計畫快取中找出「總計」耗費最多邏輯讀取 (Logical Reads) 的 SQL 語法。
    結果 : 總執行次數、總邏輯讀取量、單次平均讀取、CPU時間(毫秒)、總花費時間(毫秒)、擷取出的實際單句語法，及完整 SQL。
    限制 : 僅能取得目前仍在「記憶體」快取中的資料。若重啟服務、清空快取或因記憶體壓力被洗掉則查不到。WITH RECOMPILE 的查詢也不會統計。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 日常排查造成整體系統 I/O 與 CPU 負載極高的元凶 (執行次數多且讀取量大的語法)。
*/
SELECT TOP 20
    qs.execution_count AS [總執行次數],
    qs.total_logical_reads AS [總邏輯讀取次數],
    (qs.total_logical_reads / qs.execution_count) AS [單次平均邏輯讀取],
    qs.total_worker_time / 1000.0 AS [總累計CPU時間(毫秒)],
    qs.total_elapsed_time / 1000.0 AS [總花費時間(毫秒)],
    SUBSTRING(t.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
          WHEN -1 THEN DATALENGTH(t.text)
         ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS [實際執行的單句語法],
    t.text AS [完整SQL或預存程序內容]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
WHERE qs.total_logical_reads > 0
ORDER BY qs.total_logical_reads DESC;

--============================================================================================================

/*
    目的 : 從執行計畫快取中找出「單次平均」邏輯讀取最高的 SQL 語法。
    結果 : 總執行次數、總邏輯讀取量、單次平均邏輯讀取、CPU時間(毫秒)、總花費時間(毫秒)及 SQL 語法內容。
    限制 : 依賴於記憶體快取。若該語法執行頻率極低且已被移出快取則抓不到。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 進行資料庫日常健康檢查，想揪出寫法不佳、缺少關鍵索引 (例如導致 Table Scan) 的肥大查詢時。
*/
SELECT TOP 20
    qs.execution_count AS [總執行次數],
    qs.total_logical_reads AS [總邏輯讀取次數],
    (qs.total_logical_reads / qs.execution_count) AS [單次平均邏輯讀取],
    qs.total_worker_time / 1000.0 AS [總累計CPU時間(毫秒)],
    qs.total_elapsed_time / 1000.0 AS [總花費時間(毫秒)],
    SUBSTRING(t.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
          WHEN -1 THEN DATALENGTH(t.text)
         ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS [實際執行的單句語法],
    t.text AS [完整SQL或預存程序內容]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
WHERE qs.total_logical_reads > 0
ORDER BY (qs.total_logical_reads / qs.execution_count) DESC;

--============================================================================================================

/*
    目的 : 從執行計畫快取中找出「單次平均」花費時間 (Elapsed Time) 最長的 SQL 語法。
    結果 : 總執行次數、總邏輯讀取量、單次平均邏輯讀取、CPU時間(毫秒)、單次平均花費時間(秒)及 SQL 語法內容。
    限制 : 依賴於記憶體快取。Elapsed Time 包含等待時間 (網路延遲、Lock)，因此時間長不代表一定是運算效率差，需配合 Wait Stats 釐清。
    權限 : 需要 VIEW SERVER STATE 權限。
    時機 : 想要巡檢目前系統快取中，平均單次耗時最久，最拖慢使用者體驗的慢查詢語法。
*/
SELECT TOP 20
    qs.execution_count AS [總執行次數],
    qs.total_logical_reads AS [總邏輯讀取次數],
    (qs.total_logical_reads / qs.execution_count) AS [單次平均邏輯讀取],
    qs.total_worker_time / 1000.0 AS [總累計CPU時間(毫秒)],
    qs.total_elapsed_time / 1000.0 AS [總花費時間(毫秒)],
    SUBSTRING(t.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
          WHEN -1 THEN DATALENGTH(t.text)
         ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS [實際執行的單句語法],
    t.text AS [完整SQL或預存程序內容]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
WHERE qs.total_logical_reads > 0
ORDER BY (qs.total_elapsed_time / 1000.0 / qs.execution_count) DESC;

--============================================================================================================

-- 請執行下面這段，直接從目前的記憶體快取中，把「剛剛跑完的那個巨大交易」挖出來！
-- 就算 SPID 被 KILL 了，它曾經耗費的龐大資源軌跡依然會留在記憶體中 (直到重開機或快取被洗掉)
SELECT TOP 10
    qs.execution_count AS [總執行次數],
    qs.total_logical_reads AS [總邏輯讀取],
    qs.total_worker_time / 1000.0 AS [總CPU時間(毫秒)],
    qs.total_elapsed_time / 1000.0 AS [總花費時間(毫秒)],
    qs.last_execution_time AS [最後執行時間],
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset 
          WHEN -1 THEN DATALENGTH(st.text) 
         ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS [最操資源的單句語法],
    st.text AS [完整SQL或預存程序內容]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
-- 【修改處】只篩選最後執行時間在過去 2 天內 (使用當地時間 GETDATE)
WHERE qs.last_execution_time >= DATEADD(DAY, -7, GETDATE())
ORDER BY qs.total_logical_reads DESC;



-- 1. 先把目標事件抓到暫存表 
IF OBJECT_ID('tempdb..#XeData') IS NOT NULL DROP TABLE #XeData;

SELECT 
    object_name, 
    CAST(event_data AS XML) AS event_data_XML
INTO #XeData
FROM sys.fn_xe_file_target_read_file('system_health*.xel', null, null, null)
WHERE object_name IN ('wait_info', 'xml_deadlock_report');

-- 2. 再從暫存表解析 XML 
SELECT TOP 50
    object_name AS [事件類型],
    event_data_XML.value('(/event/@timestamp)[1]', 'datetime2') AS [UTC發生時間],
    event_data_XML.value('(/event/data[@name="wait_type"]/text)[1]', 'varchar(50)') AS [等待類型],
    event_data_XML.value('(/event/data[@name="duration"]/value)[1]', 'bigint') / 1000.0 AS [等待時間(毫秒)],
    event_data_XML.value('(/event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [當時執行的SQL],
    event_data_XML.value('(/event/action[@name="session_id"]/value)[1]', 'int') AS [SPID],
    event_data_XML AS [完整XML詳細資料]
FROM #XeData
WHERE event_data_XML.value('(/event/@timestamp)[1]', 'datetime2') >= DATEADD(DAY, -7, GETUTCDATE())
ORDER BY [UTC發生時間] DESC;

-- 3. 清理暫存表
DROP TABLE #XeData;