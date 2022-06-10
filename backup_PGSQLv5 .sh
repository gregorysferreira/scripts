#!/bin/bash

source /scripts/bkp_PGSQLv5_parametros

reindexTB()
{
	for TABELA in ${TABELAS[@]}; do
	  /usr/bin/psql -U bkpzabbix zabbix -c "reindex table $TABELA" && echo "OK - reindex $TABELA" >> $LOGREVAC || echo "ERRO - reindex table" >> $LOGREVAC
	done
}

reindexDB()
{
	/usr/bin/psql -U bkpzabbix zabbix -c "reindex database zabbix" && echo "OK - reindex database" >> $LOGREVAC || echo "ERRO - reindex database" >> $LOGREVAC
}

vacuumana()
{
        /usr/bin/psql -U bkpzabbix zabbix -c "vacuum analyze" && echo "OK - vacuum analyze" >> $LOGREVAC || echo "ERRO - vacuum analyze" >> $LOGREVAC
}
vacuumful()
{
	if [ $(date +%u) -eq 7 ]; then
		/usr/bin/psql -U bkpzabbix zabbix -c "vacuum full" && echo "OK - vacuum full" >> $LOGREVAC || echo "ERRO - vacuum full" >> $LOGREVAC
	fi
}

send_mail()
{
        source /scripts/bkp_PGSQLv5_parametros
        echo -e "Verificar com urgencia o status de backup do banco de dados de $(HOSTNAME) ocorrido em $DATALOG em $DESTINOBASE" | mail -s "$HOSTNAME - ERRO NO PROCESSO DE BACKUP... LOG LOCALIZADO EM $LOGBANCO" ${TO[$x]}
        echo -e "$DATALOG $LOGBANCO: Email de notificação enviado para $TO" >> $LOGBANCO
        exit 0
}

trap_error()
{
        echo -e "$DATALOG: Erro na execucao do script de backup de banco BACKUP DE $DATAHORA NAO REALIZADO" >> $LOGBANCO
        /bin/rm -rvf $DESTINO >> $LOGBANCO
        send_mail
        exit 0
}
trap 'trap_error' 1 2 3 5 6 15 25

#Validar se existem discos a serem montados
if [ $QTDISCO -eq 0 ];
then
        echo "OK Nao existem particoes a serem montadas"
        echo "Destino de backup em /dados/backup/PGSQL"
        DESTINO="/$DESTINOBASE/$DATAHORA"
elif [ ! -d $DESTINOBASE ];
then
        for i in $(seq $QTDISCO); do
                PONTOMONTAGEM=$(cat /etc/fstab | grep -o "/mnt/.*" | cut -d " " -f1 | head -n $i);
                sleep 2
                mount $PONTOMONTAGEM
                ESPACODISCO=$(df $DESTINOBASE | grep $DISCOMONTAGEM | sed -E "s/.* (.*)% .*$/\1/g")
        done
else
        echo -e "$DATALOG: Discos montados, iniciando processo de backup" >> $LOGBANCO
fi
sleep 2
ESPACODISCO="$( df $DESTINOBASE | sed -E "s/.* (.*)% .*$/\1/g" | tail -n 1)"

#Executando backup
if [ "$ESPACODISCO" -lt $LIMITEDISCO -a -d $DESTINOBASE ] ;
then

#Removendo backup antigo
        find $DESTINOBASE -maxdepth 1 -ctime +$MAXRET -exec rm -rfv "{}" \; >> $LOGBANCO && echo "$DATALOG: Removido backups com mais de $MAXRET dias" >> $LOGBANCO
        
#Cria pasta no destino com data/hora
       /bin/mkdir -p "$DESTINO"

#Gerando backup de banco
       echo "$DATALOG: Gerando Backup Base - zabbix em: $DESTINO" >> $LOGBANCO
       /usr/bin/pg_dump -U zabbix $BASE | gzip -9 > $DESTINO/bkp_base_$BASE.sql.gz
       echo "$DATALOG: Backup criado: $DESTINO/bkp_base_$BASE.sql.gz" >> $LOGBANCO

else
        echo "$DATALOG: $PONTOMONTAGEM com menos de $((100 - $LIMITEDISCO))% de espaço livre." >> $LOGBANCO;
        send_mail
fi

#Verificação se Reindex(Tabela/Banco) e Vaccum(Analyse/FULL) estão habilitados para execução

echo "$DATALOG" > $LOGREVAC

case $REINDEXDB in 1) reindexDB ;; esac

case $REINDEXTB in 1) reindexTB ;; esac

case $VACUUMANA in 1) vacuumana ;; esac

case $VACUUMFUL in 1) vacuumful ;; esac

