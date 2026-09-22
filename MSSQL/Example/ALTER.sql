--====================準備資料====================
CREATE TABLE Person (
    ID INT IDENTITY(1, 1),
    LastName VARCHAR(255) NOT NULL,
    FirstName VARCHAR(255),
    Age INT,
    City VARCHAR(255) CONSTRAINT DF_City DEFAULT 'Sandnes'
);

INSERT INTO Person (LastName, FirstName, Age)
SELECT 'Sean', 'Ho', 22
UNION SELECT 'John', 'Chen', 30
UNION SELECT 'Kenny', 'Ken', 35

SELECT A.TABLE_NAME, A.COLUMN_NAME, A.DATA_TYPE, A.CHARACTER_MAXIMUM_LENGTH--, B.[value]
FROM INFORMATION_SCHEMA.COLUMNS A WHERE A.TABLE_NAME = 'Person'
SELECT * FROM Person
--================================================

--====================增加欄位====================
/*
ALTER TABLE [Table]
ADD [ColumnName] [DataType];
*/
ALTER TABLE Person
ADD DateOfBirth DATE;

SELECT * FROM Person
--================================================

--====================刪除欄位====================
/*
ALTER TABLE [Table]
DROP COLUMN [ColumnName];
*/
ALTER TABLE Person
DROP COLUMN DateOfBirth;

SELECT * FROM Person
--================================================

--====================重新定義欄位型態==============
/*
ALTER TABLE [Table]
ALTER COLUMN [ColumnName] [DataType];
*/
ALTER TABLE Person
ALTER COLUMN Age VARCHAR(3);

SELECT A.TABLE_NAME, A.COLUMN_NAME, A.DATA_TYPE, A.CHARACTER_MAXIMUM_LENGTH--, B.[value]
FROM INFORMATION_SCHEMA.COLUMNS A WHERE A.TABLE_NAME = 'Person'
--================================================

--====================刪除約束=====================
/*
ALTER TABLE [Table]
DROP CONSTRAINT [ConstraintName];

Note:查看約束
SELECT name 
FROM sys.default_constraints 
WHERE parent_object_id = OBJECT_ID([Table]) 
AND parent_column_id = COLUMNPROPERTY(OBJECT_ID([Table]), [ColumnName], 'ColumnId');
*/
ALTER TABLE Person
DROP CONSTRAINT DF_City;

INSERT INTO Person (LastName, FirstName, Age)
SELECT 'Dan', 'Lee', '25'

SELECT * FROM Person
SELECT name 
FROM sys.default_constraints 
WHERE parent_object_id = OBJECT_ID('Person') 
AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('Person'), 'City', 'ColumnId');
--================================================

--====================新增約束=====================
/*
ALTER TABLE [Table]
ADD CONSTRAINT [ConstraintName]
DEFAULT [DefaultValue] FOR [Column];
*/
ALTER TABLE Person
ADD CONSTRAINT DF_City
DEFAULT 'NewYork' FOR City;

INSERT INTO Person (LastName, FirstName, Age)
SELECT 'Dan', 'Lee', '25'

SELECT * FROM Person
SELECT name 
FROM sys.default_constraints 
WHERE parent_object_id = OBJECT_ID('Person') 
AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('Person'), 'City', 'ColumnId');
--================================================
DROP TABLE Person