# ============================================================
# Versao PowerShell do setup de replicacao (Windows).
# Uso:  powershell -ExecutionPolicy Bypass -File scripts/setup_replication.ps1
# ============================================================
$ErrorActionPreference = "Stop"

$Master = "mysql_master"
$Slaves = @("mysql_slave1", "mysql_slave2", "mysql_slave3")
$RootPass = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { "rootpassword" }

Write-Host ">>> Aguardando o Master responder..."
do {
  docker exec $Master mysqladmin ping -h localhost -p"$RootPass" --silent 2>$null
  if ($LASTEXITCODE -ne 0) { Start-Sleep -Seconds 2 }
} while ($LASTEXITCODE -ne 0)
Write-Host ">>> Master OK."

foreach ($Slave in $Slaves) {
  Write-Host ">>> Configurando replicacao em $Slave ..."
  do {
    docker exec $Slave mysqladmin ping -h localhost -p"$RootPass" --silent 2>$null
    if ($LASTEXITCODE -ne 0) { Start-Sleep -Seconds 2 }
  } while ($LASTEXITCODE -ne 0)

  $sql = "STOP REPLICA; CHANGE REPLICATION SOURCE TO SOURCE_HOST='$Master', SOURCE_USER='repl', SOURCE_PASSWORD='replpassword', SOURCE_AUTO_POSITION=1; START REPLICA;"
  docker exec $Slave mysql -uroot -p"$RootPass" -e $sql
  Write-Host ">>> $Slave configurado."
}

Write-Host ""
Write-Host ">>> Status da replicacao:"
foreach ($Slave in $Slaves) {
  Write-Host "--- $Slave ---"
  docker exec $Slave mysql -uroot -p"$RootPass" -e "SHOW REPLICA STATUS\G" | Select-String "Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source"
}
Write-Host ""
Write-Host ">>> Replicacao ativa! IO e SQL threads devem estar em 'Yes'."
