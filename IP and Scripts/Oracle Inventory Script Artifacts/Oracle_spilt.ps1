$string = (Get-Content 'C:\1\Oracle\output_level1.txt') -join  [System.Environment]::NewLine
$arr = $string -split '(?=\/\*.*\*\/)' | ForEach-Object {
    if(($_ -join [System.Environment]::NewLine) -match '(?smi)(\/\*(?<TableName>.*)\*\/)(.*)COUNT\(\*\)\r\n-+\s+(?<Count>\d+)') {
        [pscustomobject]@{
            ObjName = $Matches.TableName
            Count     = $Matches.Count
        }
    }
}
$arr | Export-Csv -NoTypeInformation -Path 'c:\1\Oracle\11_out.csv'
