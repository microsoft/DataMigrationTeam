update [WideWorldImporters].[Sales].[Orders] set comments='Test firing of CLR trigger on 5 row update', PerfTest=SYSDATETIME() where OrderID between 1 and 5;
