--=========================代理作業類=======================
IF(1 = 0)
--SQL Server 代理作業 (SQL Agent Jobs)：檢查排程作業的最後執行狀態
SELECT 
    j.name AS [JobName]             --作業名稱
    , j.enabled                     --是否啟用 (1=是)
    , h.run_date                    --最後執行日期 (格式 YYYYMMDD)
    , h.run_time                    --最後執行時間 (格式 HHMMSS)
    , h.run_status                  --執行結果 (1=成功, 0=失敗)
    , h.message                     --系統回傳的錯誤或成功訊息
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.instance_id = (
    SELECT MAX(instance_id) 
    FROM msdb.dbo.sysjobhistory 
    WHERE job_id = j.job_id
)

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_help_job: 快速查看 SQL Agent 內部作業的詳細設定與排程
    EXEC msdb.dbo.sp_help_job;
END