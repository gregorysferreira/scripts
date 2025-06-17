#!/bin/bash
# Author: Gregory Ferreira
# Date: 2025-06-12 
# Version : 1.0
# Description: Script para automatizar a restauração de um banco de dados PostgreSQL a partir de um dump remoto.


# Configurações
REMOTE_USER="root"             
REMOTE_HOST="192.168.30.244"
REMOTE_PORT="1024"
REMOTE_BACKUP_DIR="/dados/backup/PGSQL/"
LOCAL_RESTORE_DIR="/tmp/restore_pgsql"
DB_NAME="dbcallcenter"
DB_USER="postgres"
LOG_FILE="/var/log/restore_automation.log"

DUMP_FILENAME="bkp_base_dbcallcenter.sql.gz"
DUMP_UNZIPPED="bkp_base_dbcallcenter.sql"

# Função de log
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "==== Início do processo de restauração do banco $DB_NAME ===="

# Criar diretório de trabalho
mkdir -p "$LOCAL_RESTORE_DIR"

# Obter o diretório mais recente no servidor remoto
log "Verificando diretório mais recente no servidor remoto..."
LATEST_DIR=$(ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" \
  "ls -1dt $REMOTE_BACKUP_DIR*/ | head -n 1")
BASE_DIR_NAME=$(basename "$LATEST_DIR")
log "Diretório identificado: $BASE_DIR_NAME"

# Sincronizar o dump via rsync com chave SSH e porta 1024
log "Iniciando rsync do arquivo $DUMP_FILENAME..."
rsync -avz -e "ssh -p $REMOTE_PORT -o StrictHostKeyChecking=no" \
  "$REMOTE_USER@$REMOTE_HOST:$LATEST_DIR/$DUMP_FILENAME" "$LOCAL_RESTORE_DIR/" >> "$LOG_FILE" 2>&1

if [[ ! -f "$LOCAL_RESTORE_DIR/$DUMP_FILENAME" ]]; then
  log "❌ Erro: Arquivo $DUMP_FILENAME não encontrado após sincronização."
  exit 1
fi

# Descompactar
log "Descompactando dump..."
gunzip -f "$LOCAL_RESTORE_DIR/$DUMP_FILENAME"

if [[ ! -f "$LOCAL_RESTORE_DIR/$DUMP_UNZIPPED" ]]; then
  log "❌ Erro: Falha ao descompactar o dump."
  exit 1
fi

# Matar conexões existentes
log "Encerrando conexões ativas com o banco $DB_NAME..."
psql -U "$DB_USER" -d postgres -c "
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
  log "❌ Erro ao encerrar conexões com o banco $DB_NAME."
  exit 1
fi

# Dropar e recriar banco
log "Dropando banco $DB_NAME..."
psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;" >> "$LOG_FILE" 2>&1

log "Recriando banco $DB_NAME..."
psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" >> "$LOG_FILE" 2>&1

# Restaurar o banco
log "Restaurando dump no banco $DB_NAME..."
psql -U "$DB_USER" -d "$DB_NAME" -f "$LOCAL_RESTORE_DIR/$DUMP_UNZIPPED" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
  log "❌ Erro na restauração do dump no banco $DB_NAME."
  exit 1
fi

# Reindex
log "Executando REINDEX DATABASE $DB_NAME..."
psql -U "$DB_USER" -d "$DB_NAME" -c "REINDEX DATABASE $DB_NAME;" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
  log "❌ Erro durante o REINDEX do banco $DB_NAME."
  exit 1
fi

# Vacuum só após REINDEX com sucesso
log "Executando VACUUM FULL ANALYZE..."
psql -U "$DB_USER" -d "$DB_NAME" -c "VACUUM FULL ANALYZE;" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
  log "❌ Erro durante o VACUUM FULL ANALYZE do banco $DB_NAME."
  exit 1
fi

log "✅ Processo de restauração do banco $DB_NAME concluído com sucesso."
log "==== Fim do processo ===="
