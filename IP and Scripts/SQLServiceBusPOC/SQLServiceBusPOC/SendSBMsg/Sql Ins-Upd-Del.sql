/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
INSERT INTO [dbo].[foo] ([a],[bar],[bigstuff],[modified])
VALUES (5, 42, 'TESTING TESTING 123', getdate())
GO
update [test].[dbo].[foo]
set bigstuff='TESTING-Interation-39- CLR Trigger'
where a in (2,3)
go
/*
delete from foo where a=5
*/
go