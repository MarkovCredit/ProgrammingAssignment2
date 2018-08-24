SELECT COLUMN_NAME, TABLE_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE COLUMN_NAME LIKE '%amount_received%'


---
SELECT convert(char(10), getdate(), 101) AS TheDate, 
CAST(year(getdate()) AS char(4)) + '-Q' + 
    CAST(CEILING(CAST(month(getdate()) AS decimal(4,2)) / 3) AS char(1)) AS SelectQuarter 
