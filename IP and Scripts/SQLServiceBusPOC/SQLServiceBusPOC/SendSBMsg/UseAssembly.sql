/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
use WideWorldImporters
go
DROP TRIGGER sales.testclr_SO
GO
DROP TRIGGER sales.testclr_SOL
GO
DROP TRIGGER sales.testclr_SI
GO
DROP ASSEMBLY SendSBMsg;
GO
CREATE ASSEMBLY SendSBMsg FROM 'C:\Users\mivanhuu\source\repos\DMJGitSourceControl\Private\IP and Scripts\Tools\SQLServiceBusPOC\SendSBMsg\bin\Debug\SendSBMsg.dll' WITH PERMISSION_SET = UNSAFE; 
go
CREATE TRIGGER testclr_SO
ON Sales.Orders 
FOR INSERT, UPDATE, DELETE  
AS  
EXTERNAL NAME SendSBMsg.CLRTriggers.trgSendSBMsg;  
go
CREATE TRIGGER testclr_SOL
ON Sales.OrderLines 
FOR INSERT, UPDATE, DELETE  
AS  
EXTERNAL NAME SendSBMsg.CLRTriggers.trgSendSBMsg;  
go
CREATE TRIGGER testclr_SI
ON Sales.Invoices
FOR INSERT, UPDATE, DELETE  
AS  
EXTERNAL NAME SendSBMsg.CLRTriggers.trgSendSBMsg;  
go