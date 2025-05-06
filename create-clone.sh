#!/bin/bash

if [ -z "$1" ]; then
    echo "Uso: $0 <last-month>"
    exit 1
fi

BASE_DIR="/var/www/html/xml"
REMOTE_PATH="xml/woo_pdv"
RCLONE_REMOTE="gdrive-sa"
LOG_FILE="/var/log/rclone-woo-pdv.log"

# Função para calcular o ano e mês anterior
get_last_month() {
    local current_year=$(date +%Y)
    local current_month=$(date +%m)

    if [ "$current_month" -eq 1 ]; then
        last_month=12
        last_year=$((current_year - 1))
    else
        last_month=$((current_month - 1))
        last_year=$current_year
    fi

    printf "%04d %02d\n" "$last_year" "$last_month"
}

compactar() {
    local loja_path=$1
    local zip_file=$2

    echo "Compactando o conteúdo de $loja_path para $zip_file..." | tee -a "$LOG_FILE"

    if [ -d "$loja_path" ]; then
        if [ "$(ls -A "$loja_path")" ]; then
            (cd "$loja_path" && zip -r "$zip_file" .) >> "$LOG_FILE" 2>&1
        else
            echo "Diretório $loja_path está vazio. Nada para compactar." | tee -a "$LOG_FILE"
            return 1
        fi
    else
        echo "Diretório $loja_path não encontrado." | tee -a "$LOG_FILE"
        return 1
    fi
}

enviar_para_google_drive() {
    local zip_file=$1
    local remote_dest=$2

    echo "Enviando $zip_file para $remote_dest no Google Drive..." | tee -a "$LOG_FILE"
    rclone copy "$zip_file" "$remote_dest" --drive-server-side-across-configs -v --update >> "$LOG_FILE" 2>&1

    echo "Removendo arquivo local $zip_file..." | tee -a "$LOG_FILE"
    rm -f "$zip_file"
}

processar_mes() {
    local ano=$1
    local mes=$2
    local mes_path="$BASE_DIR/$ano/$mes"
    local remote_dest="$RCLONE_REMOTE:$REMOTE_PATH/$ano/$mes"

    echo "Processando mês: $ano/$mes..." | tee -a "$LOG_FILE"

    for loja in "$mes_path"/*; do
        if [ -d "$loja" ]; then
            local loja_name=$(basename "$loja")
            local zip_file="/tmp/${ano}_${mes}_${loja_name}.zip"

            compactar "$loja" "$zip_file"
            enviar_para_google_drive "$zip_file" "$remote_dest"
        fi
    done
}

# Verifica se o parâmetro é "last-month"
if [ "$1" == "last-month" ]; then
    read last_year last_month <<< $(get_last_month)

    # Processa apenas o mês anterior
    if [ -d "$BASE_DIR/$last_year/$last_month" ]; then
        processar_mes "$last_year" "$last_month"
    else
        echo "Pasta $BASE_DIR/$last_year/$last_month não encontrada, encerrando." | tee -a "$LOG_FILE"
    fi
else
    echo "Uso: $0 last-month" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Processo concluído!" | tee -a "$LOG_FILE"