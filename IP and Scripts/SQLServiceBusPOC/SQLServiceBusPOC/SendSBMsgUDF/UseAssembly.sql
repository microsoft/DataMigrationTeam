/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
DROP TRIGGER testclr	-- drop CLR trigger in case it is active
GO

-- Register CLR Assembly and associated function
DROP FUNCTION SendSBMsg
go
DROP ASSEMBLY SendSBMsgUDF;
GO
CREATE ASSEMBLY SendSBMsgUDF FROM 'C:\Users\mivanhuu\source\repos\DMJGitSourceControl\Private\IP and Scripts\Tools\SQLServiceBusPOC\SendSBMsgUDF\bin\Debug\SendSBMsgUDF.dll' WITH PERMISSION_SET = UNSAFE; 
go
CREATE FUNCTION SendSBMsg(@msgbody nvarchar(max))
RETURNS nvarchar(max)
AS  
EXTERNAL NAME SendSBMsgUDF.CLRUDF.SendSBMsgUDF;  
go

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DIRECT SEND TO SERVICE BUS TRIGGER
drop trigger trgsenddirect_SO
go
create trigger trgsenddirect_SO on Sales.Orders
for insert, update, delete
as
declare @inserted int
select @inserted=count(*) from inserted
declare @msgbody nvarchar(max)
if (@inserted > 0)
 begin
	set @msgbody = (select * from inserted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>insert</action><table>Sales.Orders</table><rows>' + @msgbody + '</rows></message>'
 end
else
 begin
	set @msgbody = (select * from deleted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>delete</action><table>Sales.Orders</table><rows>' + @msgbody + '</rows></message>'
 end
select dbo.SendSBMsg(@msgbody)
go
drop trigger trgsenddirect_SOL
go
create trigger trgsenddirect_SOL on Sales.OrderLines
for insert, update, delete
as
declare @inserted int
select @inserted=count(*) from inserted
declare @msgbody nvarchar(max)
if (@inserted > 0)
 begin
	set @msgbody = (select * from inserted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>insert</action><table>Sales.OrderLines</table><rows>' + @msgbody + '</rows></message>'
 end
else
 begin
	set @msgbody = (select * from deleted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>delete</action><table>Sales.OrderLines</table><rows>' + @msgbody + '</rows></message>'
 end
select dbo.SendSBMsg(@msgbody)
go
drop trigger trgsenddirect_SI
go
create trigger trgsenddirect_SI on Sales.Invoices
for insert, update, delete
as
declare @inserted int
select @inserted=count(*) from inserted
declare @msgbody nvarchar(max)
if (@inserted > 0)
 begin
	set @msgbody = (select * from inserted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>insert</action><table>Sales.Invoices</table><rows>' + @msgbody + '</rows></message>'
 end
else
 begin
	set @msgbody = (select * from deleted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>delete</action><table>Sales.Invoices</table><rows>' + @msgbody + '</rows></message>'
 end
select dbo.SendSBMsg(@msgbody)
go

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SEND TO SERVICE BUS VIA SERVICE BROKER TRIGGER (Service Broker queue and contracts need to be set up)
drop trigger trgSBtest_SO
go
create trigger trgSBtest_SO on Sales.Orders
for insert, update, delete
as
declare @inserted int
select @inserted=count(*) from inserted
declare @msgbody nvarchar(max)
if (@inserted > 0)
 begin
	set @msgbody = (select * from inserted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>insert</action><table>Sales.Orders</table><rows>' + @msgbody + '</rows></message>'
 end
else
 begin
	set @msgbody = (select * from deleted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>delete</action><table>Sales.Orders</table><rows>' + @msgbody + '</rows></message>'
 end
EXECUTE dbo.SendBrokerMessage
		@FromService = N'RequestService',
		@ToService   = N'ProcessingService',
		@Contract    = N'AsyncContract',
		@MessageType = N'AsyncRequest',
		@MessageBody = @msgbody
go
drop trigger trgSBtest_SOL
go
create trigger trgSBtest_SOL on Sales.OrderLines
for insert, update, delete
as
declare @inserted int
select @inserted=count(*) from inserted
declare @msgbody nvarchar(max)
if (@inserted > 0)
 begin
	set @msgbody = (select * from inserted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>insert</action><table>Sales.OrderLines</table><rows>' + @msgbody + '</rows></message>'
 end
else
 begin
	set @msgbody = (select * from deleted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>delete</action><table>Sales.OrderLines</table><rows>' + @msgbody + '</rows></message>'
 end
EXECUTE dbo.SendBrokerMessage
		@FromService = N'RequestService',
		@ToService   = N'ProcessingService',
		@Contract    = N'AsyncContract',
		@MessageType = N'AsyncRequest',
		@MessageBody = @msgbody
go
drop trigger trgSBtest_SI
go
create trigger trgSBtest_SI on Sales.Invoices
for insert, update, delete
as
declare @inserted int
select @inserted=count(*) from inserted
declare @msgbody nvarchar(max)
if (@inserted > 0)
 begin
	set @msgbody = (select * from inserted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>insert</action><table>Sales.Invoices</table><rows>' + @msgbody + '</rows></message>'
 end
else
 begin
	set @msgbody = (select * from deleted for xml path)
	select @msgbody = '<message><server>' + REPLACE(@@SERVERNAME, '\', '%5C') + '</server><action>delete</action><table>Sales.Invoices</table><rows>' + @msgbody + '</rows></message>'
 end
EXECUTE dbo.SendBrokerMessage
		@FromService = N'RequestService',
		@ToService   = N'ProcessingService',
		@Contract    = N'AsyncContract',
		@MessageType = N'AsyncRequest',
		@MessageBody = @msgbody
go