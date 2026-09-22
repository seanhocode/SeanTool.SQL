--=========================資料庫結構類=========================
IF(1 = 0)
--資料庫中的schema列表
SELECT name                         --Schema名稱
    , schema_id                     --Schema的唯一ID
    , principal_id                  --擁有這個schema的使用者或角色的ID，對應到sys.database_principals.principal_id
FROM sys.schemas

IF(1 = 0)
--所有資料庫物件(包含資料表、檢視、預存程序、觸發器等)
SELECT name                         --物件名稱
    , object_id                     --物件ID(在資料庫內唯一)
    , schema_id                     --所屬schema的ID
    , parent_object_id              --父物件ID(例如觸發器所屬的table)
    , type                          --物件類型代碼(例如U=使用者資料表,V=檢視,P=預存程序)
    , type_desc                     --物件類型說明
    , create_date                   --建立日期
    , modify_date                   --最後修改日期
    , is_ms_shipped                 --是否為系統內建物件(1=是)
FROM sys.objects

IF(1 = 0)
--使用者自建的資料表列表
SELECT name                         --資料表名稱
    , object_id                     --資料表的物件ID
    , schema_id                     --所屬schema的ID
    , principal_id                  --擁有者的principal ID
    , create_date                   --建立日期
    , modify_date                   --修改日期
    , is_ms_shipped                 --是否為系統內建表(1=是)
    , is_published                  --是否用於複寫(1=是)
    , is_replicated                 --是否為複寫資料表(1=是)
FROM sys.tables

IF(1 = 0)
--檢視(View)列表
SELECT name                         --檢視名稱
    , object_id                     --檢視的物件ID
    , schema_id                     --所屬schema的ID
    , create_date                   --建立日期
    , modify_date                   --修改日期
    , is_ms_shipped                 --是否為系統內建檢視(1=是)
FROM sys.views

IF(1 = 0)
--所有資料表與檢視的欄位資訊
SELECT object_id                    --所屬資料表或檢視的ID
    , name                          --欄位名稱
    , column_id                     --欄位在該物件內的序號
    , system_type_id                --系統資料型別ID
    , user_type_id                  --使用者定義資料型別ID
    , max_length                    --最大長度(byte)
    , precision                     --精度
    , scale                         --小數位數
    , is_nullable                   --是否允許NULL(1=是)
    , is_identity                   --是否為識別欄位(IDENTITY)
    , is_computed                   --是否為計算欄位
    , collation_name                --定序
FROM sys.columns

IF(1 = 0)
--計算欄位定義：查看自動計算欄位的公式
SELECT 
    object_name(object_id) AS [TableName]
    , name AS [ColumnName]
    , definition                    --計算公式
    , is_persisted                  --是否保存(實體化)
FROM sys.computed_columns

IF(1 = 0)
--資料庫中的資料型別列表(包含系統型別與使用者自訂型別)
SELECT name                         --資料型別名稱
    , system_type_id                --系統資料型別ID
    , user_type_id                  --使用者資料型別ID(對應自訂型別會不同)
    , schema_id                     --所屬schema的ID
    , principal_id                  --擁有者principal ID
    , max_length                    --最大長度(byte)
    , precision                     --精度
    , scale                         --小數位數
    , collation_name                --定序名稱(僅字串型別適用)
    , is_nullable                   --是否可為NULL(1=是)
    , is_user_defined               --是否為使用者自訂型別(1=是)
    , is_assembly_type              --是否為CLR組件型別(1=是)
    , default_object_id             --預設值約束的object ID(無則為0)
    , rule_object_id                --檢查規則的object ID(無則為0)
FROM sys.types

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- sp_help: 快速查詢特定物件的詳細結構(包含欄位、型別、約束等)
    EXEC sp_help 'YourTableName';
    
    -- OBJECT_NAME(): 透過 ID 反查名稱 (常搭配 WHERE 條件使用)
    -- OBJECT_ID(): 透過名稱反查 ID
    SELECT OBJECT_NAME(123456789) AS ObjName, OBJECT_ID('YourTableName') AS ObjID;
    
    -- COL_NAME(): 透過表ID與欄位ID取得欄位名稱
    SELECT COL_NAME(OBJECT_ID('YourTableName'), 1);
END