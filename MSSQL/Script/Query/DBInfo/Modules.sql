--=========================程式物件類=========================
IF(1 = 0)
--所有預存程序
SELECT name                         --預存程序名稱
    , object_id                     --物件ID
    , schema_id                     --所屬schema的ID
    , create_date                   --建立日期
    , modify_date                   --修改日期
FROM sys.procedures

IF(1 = 0)
--所有觸發器
SELECT name                         --觸發器名稱
    , t.object_id                   --物件ID
    , parent_class_desc             --觸發對象類型(DATABASE或OBJECT)
    , parent_id                     --觸發對象的ID(例如資料表)
    , is_instead_of_trigger         --是否為INSTEAD OF觸發器
    , is_disabled                   --是否停用
    , OBJECT_DEFINITION(t.object_id) AS trigger_definition
    , m.definition
FROM sys.triggers AS t
JOIN
    sys.sql_modules AS m ON m.object_id = t.object_id

IF(1 = 0)
--所有函數的參數
SELECT object_id                    --所屬物件ID(函數或預存程序)
    , name                          --參數名稱
    , parameter_id                  --參數序號
    , system_type_id                --系統資料型別ID
    , user_type_id                  --使用者定義型別ID
    , max_length                    --最大長度
    , precision                     --精度
    , scale                         --小數位數
    , is_output                     --是否為輸出參數
FROM sys.parameters

IF(1 = 0)
--物件的SQL定義(預存程序、檢視、函數等)
SELECT object_id                    --物件ID
    , definition                    --SQL定義內容
FROM sys.sql_modules

IF(1 = 0)
--自訂擴充屬性(例如欄位註解)
SELECT major_id                     --主要物件ID(例如table的object_id)
    , minor_id                      --次要物件ID(例如column_id)
    , name                          --屬性名稱
    , value                         --屬性值
FROM sys.extended_properties

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_helptext: 將預存程序或檢視表的原始碼直接印在訊息視窗，方便複製
    EXEC sp_helptext 'YourStoredProcedureName';
    
    -- OBJECT_DEFINITION(): 函式版，直接回傳一段完整的字串
    SELECT OBJECT_DEFINITION(OBJECT_ID('YourStoredProcedureName'));
END