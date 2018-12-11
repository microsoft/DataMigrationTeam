
pip install mssql-scripter
mssql-scripter -S <servername>.database.windows.net -d <database> -U <user> -P <password> -f ./CreateSQLDWTables.dsql --script-create --target-server-version azuredw --display-progress
