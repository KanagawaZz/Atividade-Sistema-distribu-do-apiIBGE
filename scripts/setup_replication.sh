#!/usr/bin/env bash
# ============================================================
# Configura a replicacao Master -> Slaves via GTID.
# Execute APOS subir os containers (docker compose up -d).
# Uso:  bash scripts/setup_replication.sh
# ============================================================
set -e

MASTER="mysql_master"
SLAVES=("mysql_slave1" "mysql_slave2" "mysql_slave3")
ROOT_PASS="${MYSQL_ROOT_PASSWORD:-rootpassword}"

echo ">>> Aguardando o Master responder..."
until docker exec "$MASTER" mysqladmin ping -h localhost -p"$ROOT_PASS" --silent; do
  sleep 2
done
echo ">>> Master OK."

for SLAVE in "${SLAVES[@]}"; do
  echo ">>> Configurando replicacao em $SLAVE ..."
  until docker exec "$SLAVE" mysqladmin ping -h localhost -p"$ROOT_PASS" --silent; do
    sleep 2
  done
  docker exec "$SLAVE" mysql -uroot -p"$ROOT_PASS" -e "
    STOP REPLICA;
    CHANGE REPLICATION SOURCE TO
      SOURCE_HOST='$MASTER',
      SOURCE_USER='repl',
      SOURCE_PASSWORD='replpassword',
      SOURCE_AUTO_POSITION=1;
    START REPLICA;
  "
  echo ">>> $SLAVE configurado."
done

echo ""
echo ">>> Status da replicacao:"
for SLAVE in "${SLAVES[@]}"; do
  echo "--- $SLAVE ---"
  docker exec "$SLAVE" mysql -uroot -p"$ROOT_PASS" -e \
    "SHOW REPLICA STATUS\G" | grep -E "Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source"
done
echo ""
echo ">>> Replicacao ativa! IO e SQL threads devem estar em 'Yes'."
