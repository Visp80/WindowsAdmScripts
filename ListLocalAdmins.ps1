
$servers = Get-Content ".\servers.txt"

foreach ($server in $servers) {
    try {
        $admins = Get-LocalGroupMember -ComputerName $server -Group "Administrators"
        $admins | Select-Object @{Name="Server";Expression={$server}}, Name, ObjectClass | Export-Csv -Append -NoTypeInformation -Path ".\admins_report.csv"
    } catch {
        Write-Warning "Не удалось подключиться к $server: $_"
    }
}
