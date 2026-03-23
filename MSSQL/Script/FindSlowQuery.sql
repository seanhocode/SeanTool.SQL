/*
========================================================================================
Description：
    從計畫快取 (Plan Cache) 中找出指定時間區間內，平均執行時間最長的 SQL 語句。
適用情境：
    1. 資料庫變慢時，定位效能瓶頸
    2. 針對特定日期進行效能稽核
    3. 分析哪些語句造成高 CPU 或 高 I/O (Logical Reads) 負擔
Note：
    - 此腳本依賴 sys.dm_exec_query_stats，若服務重啟或手動清空快取，資料將重置
    - 時間單位已從微秒 (microseconds) 轉換為毫秒 (ms)
    - 語法已處理 Unicode Offset / 2 的字元轉換問題
========================================================================================
*/

SELECT TOP 20
    st.text AS [CompleteBatchText],
    SUBSTRING(
        st.text, (qs.statement_start_offset/2) + 1,
        (
            (
                CASE statement_end_offset
                    WHEN -1 
                        THEN DATALENGTH(st.text)
                    ELSE 
                        qs.statement_end_offset
                    END
                - qs.statement_start_offset
            )　/　2
        ) + 1
    ) AS [StatementText],
    qs.execution_count AS [ExecutionCount],
    qs.total_elapsed_time / 1000.0 AS [TotalElapsedTime(ms)],
    qs.total_elapsed_time / qs.execution_count / 1000.0 AS [AvgElapsedTime(ms)],
    qs.total_worker_time / 1000.0 AS [TotalCPUTime(ms)],
    qs.total_logical_reads AS [TotalLogicalReads],
    qs.last_execution_time AS [LastExecutionTime],
    qs.creation_time AS [PlanCreationTime]
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
--WHERE
--    qs.last_execution_time BETWEEN '2026-01-01 00:00:00' AND '2026-01-01 23:59:59'
--    AND st.text NOT LIKE '%sys.dm_exec_query_stats%'
ORDER BY [AvgElapsedTime(ms)] DESC