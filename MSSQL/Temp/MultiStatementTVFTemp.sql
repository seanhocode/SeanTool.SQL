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
需明確定義回傳表的 Schema，並包含 BEGIN...END 區塊(類似sp)
-- Ex.
        select * from  
-- =============================================
*/
CREATE FUNCTION [dbo].[] (
    @TenantID           VARCHAR(20)
    , @CompanyPartyID   BIGINT
)
RETURNS @Result TABLE 
(

)
AS
BEGIN



    RETURN 

END
GO