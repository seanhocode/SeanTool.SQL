DROP FUNCTION [dbo].[]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- =============================================
-- Author:      <SeanHo>
-- Create date: <yyyy.mm.dd>
-- Description: <>
僅包含單一 SELECT 陳述式，不需定義回傳表結構(類似View)
-- Ex.
        select * from  
-- =============================================
*/
CREATE FUNCTION [dbo].[] (
    @TenantID           VARCHAR(20)
    , @CompanyPartyID   BIGINT
)
RETURNS TABLE 
AS
RETURN (
    
)

GO


