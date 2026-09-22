/*
========================================================================================
Description：
    追蹤某段 SQL 語法的執行時間，並將結果輸出至關聯式資料表
Note：
    - 資料來源:         建立擴充事件工作階段，在伺服器引擎層級即時攔截事件
    - 資料生命週期:     寫入預先配置的記憶體緩衝區 (Ring Buffer)，當工作階段被刪除 (DROP EVENT SESSION) 時即釋放
    - 作用範圍:         攔截當前連線 (@@SPID) 且符合設定門檻 (@DurationThreshold) 的語法
========================================================================================
*/

DECLARE @SPID INT = @@SPID,
        @DurationThreshold BIGINT = 1, -- 單位微秒， 1000 毫秒 = 1000000 微秒
        @SQL NVARCHAR(MAX)

-- 建立擴充事件工作階段
SET @SQL = N'
CREATE EVENT SESSION [Track_SPID_Duration] ON SERVER
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(sqlserver.database_name, sqlserver.sql_text)
    WHERE (sqlserver.session_id = ' + CAST(@SPID AS NVARCHAR(10)) + N' AND duration >= ' + CAST(@DurationThreshold AS NVARCHAR(20)) + N')
),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.database_name, sqlserver.sql_text)
    WHERE (sqlserver.session_id = ' + CAST(@SPID AS NVARCHAR(10)) + N' AND duration >= ' + CAST(@DurationThreshold AS NVARCHAR(20)) + N')
)
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS)
'

EXEC sp_executesql @SQL
GO

-- 啟動追蹤
ALTER EVENT SESSION [Track_SPID_Duration] ON SERVER STATE = START
GO

--此處貼上欲查詢執行時間的語法
-- ==============================================================

-- ==============================================================

-- 查詢追蹤結果 (將記憶體中的 XML 資料解析為關聯式資料表)
DECLARE @target_data XML
SELECT @target_data = CAST(target_data AS XML)
FROM sys.dm_xe_sessions AS s
JOIN sys.dm_xe_session_targets AS t ON t.event_session_address = s.address
WHERE s.name = 'Track_SPID_Duration' AND t.target_name = 'ring_buffer'

select *
FROM sys.dm_xe_sessions AS s
JOIN sys.dm_xe_session_targets AS t ON t.event_session_address = s.address
WHERE s.name = 'Track_SPID_Duration' AND t.target_name = 'ring_buffer'

SELECT
    n.value('(@timestamp)[1]', 'datetime2') AS [Time],
    n.value('(@name)[1]', 'varchar(50)') AS [EventClass],
    n.value('(data[@name="duration"]/value)[1]', 'bigint') / 1000 AS [RunTime(ms)],
    n.value('(data[@name="object_id"]/value)[1]', 'int') AS [ObjectID],
    OBJECT_NAME(n.value('(data[@name="object_id"]/value)[1]', 'int')) AS [ObjectName],
    n.value('(data[@name="statement"]/value)[1]', 'nvarchar(max)') AS [TextData],
    n.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [FullTextData]
FROM @target_data.nodes('RingBufferTarget/event') AS q(n)
ORDER BY [Time]
GO

-- 停止並刪除追蹤
ALTER EVENT SESSION [Track_SPID_Duration] ON SERVER STATE = STOP
DROP EVENT SESSION [Track_SPID_Duration] ON SERVER
GO