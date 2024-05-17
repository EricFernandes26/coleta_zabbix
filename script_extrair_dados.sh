#!/bin/bash

# Função para exibir o menu de seleção de granularidade
select_granularity() {
    PS3="Selecione a granularidade de tempo desejada: "
    options=("5 minutos" "15 minutos" "30 minutos" "1 hora" "3 horas")
    select opt in "${options[@]}"
    do
        case $opt in
            "5 minutos")
                GRANULARITY=5
                break
                ;;
            "15 minutos")
                GRANULARITY=15
                break
                ;;
            "30 minutos")
                GRANULARITY=30
                break
                ;;
            "1 hora")
                GRANULARITY=60
                break
                ;;
            "3 horas")
                GRANULARITY=180
                break
                ;;
            *) echo "Opção inválida";;
        esac
    done
}

# Exibir o menu de seleção de granularidade
select_granularity

# Configurações do banco de dados Zabbix
DB_USER="root"
DB_PASSWORD="zabbix"
DB_NAME="zabbix"

# Consulta SQL para a utilização de CPU
SQL_QUERY_CPU=$(cat << EOF
SELECT
    h.host AS host,
    FROM_UNIXTIME(MAX(h.clock)) AS data_hora,
    CONCAT(ROUND(MAX(h.value), 2), ' (%)') AS 'last(%)',
    CONCAT(ROUND(MIN(h.value), 2), ' (%)') AS 'min(%)',
    CONCAT(ROUND(AVG(h.value), 2), ' (%)') AS 'avg(%)',
    CONCAT(ROUND(MAX(h.value), 2), ' (%)') AS 'max(%)'
FROM
    (SELECT
        hosts.host AS host,
        history.clock AS clock,
        history.value AS value
    FROM
        history
    JOIN
        items ON history.itemid = items.itemid
    JOIN
        hosts ON items.hostid = hosts.hostid
    JOIN
        hosts_groups ON hosts.hostid = hosts_groups.hostid
    WHERE
        items.key_ LIKE 'system.cpu.util%'  -- Filtrando todos os itens relacionados à utilização de CPU
        AND hosts_groups.groupid = 5
        AND history.clock >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL $GRANULARITY MINUTE))
    ) AS h
GROUP BY
    h.host;
EOF
)

# Consulta SQL para a utilização de memória RAM
SQL_QUERY_MEMORY=$(cat << EOF
SELECT
    h.host AS host,
    FROM_UNIXTIME(MAX(h.clock)) AS data_hora,
    CONCAT(ROUND(MAX(h.value), 2), ' (%)') AS 'last(%)',
    CONCAT(ROUND(MIN(h.value), 2), ' (%)') AS 'min(%)',
    CONCAT(ROUND(AVG(h.value), 2), ' (%)') AS 'avg(%)',
    CONCAT(ROUND(MAX(h.value), 2), ' (%)') AS 'max(%)'
FROM
    (SELECT
        hosts.host AS host,
        history.clock AS clock,
        history.value AS value
    FROM
        history
    JOIN
        items ON history.itemid = items.itemid
    JOIN
        hosts ON items.hostid = hosts.hostid
    JOIN
        hosts_groups ON hosts.hostid = hosts_groups.hostid
    WHERE
        items.key_ LIKE 'vm.memory%'  -- Filtrando todos os itens relacionados à memória RAM
        AND hosts_groups.groupid = 5
        AND history.clock >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL $GRANULARITY MINUTE))
    ) AS h
GROUP BY
    h.host;
EOF
)

# Consulta SQL para o sistema
SQL_QUERY_SYSTEM=$(cat << EOF
SELECT
    hosts.host AS host,
    FROM_UNIXTIME(history_text.clock) AS data_hora,
    SUBSTRING_INDEX(SUBSTRING_INDEX(history_text.value, '\nName=', -1), '\n', 1) AS Name,
    SUBSTRING_INDEX(SUBSTRING_INDEX(history_text.value, '\nNumberOfCores=', -1), '\n', 1) AS NumberOfCores,
    SUBSTRING_INDEX(SUBSTRING_INDEX(history_text.value, '\nNumberOfLogicalProcessors=', -1), '\n', 1) AS NumberOfLogicalProcessors,
    SUBSTRING_INDEX(SUBSTRING_INDEX(history_text.value, '\nCapacity=', -1), '\n', 1) AS Capacity,
    SUBSTRING_INDEX(SUBSTRING_INDEX(history_text.value, '\nSpeed=', -1), '\n', 1) AS Speed,
    SUBSTRING_INDEX(SUBSTRING_INDEX(history_text.value, '\nMaxClockSpeed=', -1), '\n', 1) AS MaxClockSpeed
FROM
    history_text
JOIN
    items ON history_text.itemid = items.itemid
JOIN
    hosts ON items.hostid = hosts.hostid
JOIN
    hosts_groups ON hosts.hostid = hosts_groups.hostid
WHERE
    hosts_groups.groupid = 5
    AND history_text.itemid IN ('47386', '47659', '47660')
    AND history_text.clock >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 10 MINUTE))
ORDER BY
    history_text.clock DESC;
EOF
)

# Execução das consultas SQL e salvamento em arquivos CSV
{
    echo "CPU_Utilization"
    mysql -u"$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -B -e "$SQL_QUERY_CPU" | sed 's/\t/,/g' | tr -d '\r'

    echo ""
    echo "Memory_utilization"
    mysql -u"$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -B -e "$SQL_QUERY_MEMORY" | sed 's/\t/,/g' | tr -d '\r'

    echo ""
    echo "System_Info"
    echo "host,data_hora,Name,NumberOfCores,NumberOfLogicalProcessors,Capacity,Speed,MaxClockSpeed"
    mysql -u"$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -B -e "$SQL_QUERY_SYSTEM" | awk 'NR>1' | sed 's/\t/,/g' | tr -d '\r'
} > resultado.csv

# Convertendo arquivos CSV para XLSX
ssconvert resultado.csv resultado.xlsx

echo "Consultas concluídas com sucesso. Os resultados foram salvos em 'resultado.xlsx'"
