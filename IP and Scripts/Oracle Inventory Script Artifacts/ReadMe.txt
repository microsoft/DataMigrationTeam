Steps:
1)	Connect to Oracle With SQL+ or SQL Developers and log in to the Schema you want to assess.
2)	Open the Script “Collection_Queries v 4.2.sql” and edit the Spool section <spool "C:\output.txt"> put the correct Path.
3)	Run the Script “Collection_Queries v 4.2.sql”.
4)	Once the script is completed edit in the PS1 file the Path location for the input TXT file and the output CSV file
	Input TXT file = $string = (Get-Content 'C:\1\Oracle\output.txt')
	Output TXT file = -Path 'c:\1\Oracle\out.csv'  
