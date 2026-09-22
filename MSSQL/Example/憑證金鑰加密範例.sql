USE master
GO
ALTER DATABASE SymmetricTest
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
GO
DROP DATABASE IF EXISTS SymmetricTest
CREATE DATABASE SymmetricTest
GO
USE SymmetricTest
GO
----------------------------準備資料----------------------------

/*參考文章
https://learn.microsoft.com/zh-tw/sql/t-sql/statements/create-certificate-transact-sql?view=sql-server-ver16
https://learn.microsoft.com/zh-tw/sql/t-sql/statements/create-symmetric-key-transact-sql?view=sql-server-ver16
https://jerryyang-wxy.blogspot.com/2012/11/transact-sql-sql-server-symmetric.html
https://dotblogs.com.tw/jerrymow/2011/01/24/20997
https://sdwh.dev/posts/2021/03/SQL-Server-Encryption/
https://www.cc.ntu.edu.tw/chinese/epaper/0022/20120920_2207.html
*/



/*
        Step.1 建立CERTIFICATE(憑證)

        有效期限 EXPIRY_DATE 預設為一年
        Alter certificate 可以修改密碼，但無法變更 expiry date ，需於建立時詳細考慮過期日期
        SQL Server Service Broker 會檢查到期日，不過當憑證用於加密時，不會強制執行到期

        語法:
        CREATE CERTIFICATE [憑證名稱]                   --憑證名稱
        ENCRYPTION BY PASSWORD  = [憑證密碼]            --如果不希望私鑰受MasterKey保護則可以使用ENCRYPTION BY PASSWORD子句提用自訂密碼加密(選填)
        WITH SUBJECT            = [主旨],               --「主旨」一詞是指憑證中繼資料的欄位
        START_DATE              = [生效日期],           --憑證生效的日期
        EXPIRY_DATE             = [到期日期];           --憑證到期的日期
*/
CREATE CERTIFICATE TestCertificate              --憑證名稱
ENCRYPTION BY PASSWORD  = 'p@ssw0rdp@ssw0rd'    --如果不希望私鑰受MasterKey保護則可以使用ENCRYPTION BY PASSWORD子句提用自訂密碼加密(選填)
WITH SUBJECT            = 'TestCert',           --「主旨」一詞是指憑證中繼資料的欄位
START_DATE              = '20000101',           --憑證生效的日期
EXPIRY_DATE             = '20991231';           --憑證到期的日期

/*
        Step.2 建立SYMMETRIC KEY(對稱式金鑰)

        語法:
        CREATE SYMMETRIC KEY [金鑰名稱]                 --金鑰名稱
        WITH ALGORITHM  = [加密演算法],                 --指定加密演算法
        KEY_SOURCE      = [複雜密碼],                   --當使用相同的 KEY_SOURCE 值重新建立對稱密鑰時，SQL Server 能夠生成完全相同的對稱密鑰(選填)
                                                                --這對於在多個伺服器之間共享相同的密鑰特別有用
        IDENTITY_VALUE  = [識別片語]                    --IDENTITY_VALUE 是一個識別此密鑰的唯一值，類似於對密鑰的標籤或指紋(選填)
                                                                --當使用相同的 IDENTITY_VALUE 和 KEY_SOURCE 時，可以生成相同的對稱密鑰，這在需要對密鑰進行一致性標識時非常有用
        ENCRYPTION BY CERTIFICATE [憑證名稱]            --用TestCertificate憑證加密
*/
CREATE SYMMETRIC KEY TestSymmetricKey           --金鑰名稱
WITH ALGORITHM  = AES_256,                      --指定加密演算法
KEY_SOURCE      = 'Key source',                 --指定要從中衍生金鑰的複雜密碼(選填)
IDENTITY_VALUE  = 'TestKeyIdentity'             --指定要從中產生 GUID 來標記利用暫時金鑰加密的資料之識別片語(選填)
ENCRYPTION BY CERTIFICATE TestCertificate       --用TestCertificate憑證加密

/*
        Tip

        -- 刪除CERTIFICATE
        DROP CERTIFICATE [憑證名稱]
        -- 查詢CERTIFICATE
        SELECT * FROM sys.certificates

        -- 刪除 SYMMETRIC KEY
        DROP SYMMETRIC KEY [金鑰名稱]
        -- 查詢  SYMMETRIC KEY
        SELECT * FROM sys.symmetric_keys
        -- 取得key 的 GUID 值
        SELECT Key_GUID([金鑰名稱]) 
*/
SELECT * FROM sys.certificates
SELECT name, symmetric_key_id, algorithm_desc, create_date,key_guid FROM sys.symmetric_keys

/*
        加密、解密

        開始使用 SYMMETRIC KEY 時，記得先「開啟 Open」KEY，用完之後在「關掉 Close」
        加密欄位欄位型態:VARBINARY

        OPEN語法:
        OPEN SYMMETRIC KEY [金鑰名稱]
        DECRYPTION BY CERTIFICATE [憑證名稱]
        WITH PASSWORD = [憑證密碼]

        CLOSE語法:
        CLOSE ALL SYMMETRIC KEYS

        加密語法:
        EncryptByKey(Key_GUID('TestSymmetricKey'), [欲加密值])

        解密語法:
        CONVERT(VARCHAR, DecryptByKey([加密後值(通常為欄位)]))
*/
CREATE TABLE TestData(
    [PeopleID] BIGINT IDENTITY(1,1),
    [PeopleName] VARBINARY(MAX),
    [Phone] VARBINARY(MAX),
    [Address] VARBINARY(MAX),
    [Email] VARBINARY(MAX),
    [Account] VARBINARY(MAX),
    Age VARBINARY(MAX)
)
OPEN SYMMETRIC KEY TestSymmetricKey 
DECRYPTION BY CERTIFICATE TestCertificate
WITH PASSWORD = 'p@ssw0rdp@ssw0rd'
DELETE FROM TestData

BEGIN TRAN
INSERT INTO TestData (PeopleName, Phone, [Address], Email, Account, Age)
SELECT EncryptByKey(Key_GUID('TestSymmetricKey'), '張一')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), '0900000123')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), 'Locate1')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), 'Test1@mail.com')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), '000011112222')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), '18')
UNION ALL SELECT EncryptByKey(Key_GUID('TestSymmetricKey'), '李二')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), '0900000456')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), 'Locate2')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), 'Test2@mail.com')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), '000011113333')
        , EncryptByKey(Key_GUID('TestSymmetricKey'), '20')
COMMIT
select * from TestData
SELECT CONVERT(VARCHAR,DecryptByKey(PeopleName)) AS PeopleName 
        , CONVERT(VARCHAR,DecryptByKey(Phone)) AS Phone 
        , CONVERT(VARCHAR,DecryptByKey([Address])) AS [Address] 
        , CONVERT(VARCHAR,DecryptByKey(Email)) AS Email 
        , CONVERT(VARCHAR,DecryptByKey(Account)) AS Account 
        , CONVERT(VARCHAR,DecryptByKey(Age)) AS Age 
FROM TestData
CLOSE ALL SYMMETRIC KEYS


/*備份憑證
BACKUP CERTIFICATE TestCertificate TO FILE = 'C:\Temp\test.cert'
WITH PRIVATE KEY (
FILE = 'C:\Temp\test.key',
ENCRYPTION BY PASSWORD = 'As40943113910116', -- 指定憑證私鑰檔案的密碼
DECRYPTION BY PASSWORD = 'p@ssw0rdp@ssw0rd') -- 建立憑證時所採用的密碼


CREATE DATABASE CertTest
USE CertTest
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'p@ssw0rdp@ssw0rd';
CREATE CERTIFICATE test
FROM FILE = 'C:\Temp\test.cert'
WITH PRIVATE KEY (FILE = 'C:\Temp\test.key',
DECRYPTION BY PASSWORD = 'As40943113910116'); -- 使用憑證私鑰檔案的密碼

USE SymmetricTest
DROP DATABASE CertTest
*/

