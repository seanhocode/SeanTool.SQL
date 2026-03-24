DROP FUNCTION IF EXISTS [dbo].[fnName]
GO
SET ANSI_NULLS ON --是否能用 = NULL 判斷是否為NULL ON:不可以(預設) OFF:可以
GO
SET QUOTED_IDENTIFIER ON --是否能用單引號'、雙引號"來引字串 ON:只可以用單引號(預設) OFF:兩個都可以
GO
/****************************************************************************************
目的：     無
依存：     無
傳回值:    NVARCHAR(20)
副作用:    無
備註:      無
範例:      無
****************************************************************************************/
CREATE FUNCTION [dbo].[fnName]
(
	@param1 NVARCHAR(100),
	@param2 NVARCHAR(100)
)
RETURNS NVARCHAR(20)
AS
BEGIN
	DECLARE @Result NVARCHAR(20)

	RETURN @Result
END
GO
