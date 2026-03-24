--=========================安全性與權限類=======================
IF(1 = 0)
--資料庫層級的使用者與角色
SELECT name                         --使用者或角色名稱
    , principal_id                  --主體ID
    , type_desc                     --類型說明(例如SQL_USER, DATABASE_ROLE)
    , authentication_type_desc      --驗證類型說明
    , default_schema_name           --預設schema名稱
FROM sys.database_principals

IF(1 = 0)
--資料庫層級的權限
SELECT major_id                     --主要物件ID(例如表的object_id)
    , minor_id                      --次要物件ID(例如欄位的column_id)
    , grantee_principal_id          --被授予者的principal ID
    , grantor_principal_id          --授權者的principal ID
    , permission_name               --權限名稱(例如SELECT, UPDATE)
    , state_desc                    --權限狀態(例如GRANT, DENY, REVOKE)
FROM sys.database_permissions

IF(1 = 0)
--伺服器層級的登入帳號(Server Principals)
SELECT name                         --登入名稱
    , principal_id                  --主體ID
    , sid                           --安全性識別碼(Security Identifier)
    , type_desc                     --主體類型說明(例如SQL_LOGIN, WINDOWS_LOGIN, SERVER_ROLE)
    , create_date                   --建立日期
    , modify_date                   --修改日期
    , is_disabled                   --是否停用(1=是)
FROM sys.server_principals

IF(1 = 0)
--伺服器層級的權限(Server Permissions)
SELECT class_desc                   --權限套用的物件類別(例如ENDPOINT, LOGIN, SERVER)
    , major_id                      --主要物件ID(例如endpoint_id)
    , grantee_principal_id          --被授予者的principal ID
    , grantor_principal_id          --授權者的principal ID
    , permission_name               --權限名稱(例如CONNECT, ALTER ANY LOGIN)
    , state_desc                    --權限狀態(例如GRANT, DENY, REVOKE)
FROM sys.server_permissions

-- ==================== 常用系統 SP/FN ====================
IF(1 = 0)
BEGIN
    -- SUSER_SNAME() & USER_NAME(): 快速取得當前連線的伺服器登入名與資料庫使用者名
    SELECT SUSER_SNAME() AS [CurrentLogin], USER_NAME() AS [CurrentUser];

    -- HAS_PERMS_BY_NAME(): 檢查當前用戶是否對某物件有特定權限
    SELECT HAS_PERMS_BY_NAME('YourTableName', 'OBJECT', 'SELECT');
END