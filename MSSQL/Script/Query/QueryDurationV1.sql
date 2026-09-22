/*
========================================================================================
Description：
    查詢特定語法中，每一段獨立語法的歷史執行統計
Note：
    - 資料來源:         查詢動態管理檢視 (DMV)，讀取伺服器記憶體中的計畫快取 (Plan Cache)
    - 資料生命週期:     依賴系統快取，若 SQL Server 服務重啟或手動清空快取，資料將重置
    - 作用範圍:         預設會撈出伺服器上所有已被快取的執行計畫
========================================================================================
*/

--此處貼上欲查詢執行時間的語法
--======================================================================================
--======================================================================================
SELECT TOP 20
    st.text AS [CompleteBatchText],
    SUBSTRING(
        st.text, (qs.statement_start_offset / 2) + 1,
        (
            (
                CASE statement_end_offset
                    WHEN -1 
                        THEN DATALENGTH(st.text)
                    ELSE 
                        qs.statement_end_offset
                    END
                - qs.statement_start_offset
            ) / 2
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