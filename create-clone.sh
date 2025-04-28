#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Uso: $0 <BASE_DIR> <REMOTE_PATH>"
    exit 1
fi

BASE_DIR="$1"
REMOTE_PATH="$2"
RCLONE_REMOTE="gdrive-sa"
LOG_FILE="/var/log/rclone-woo-pdv.log"

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
        fi
    done

    # Envia todos os arquivos compactados do mês
    for zip_file in /tmp/${ano}_${mes}_*.zip; do
        if [ -f "$zip_file" ]; then
            enviar_para_google_drive "$zip_file" "$remote_dest"
        fi
    done
}

for ano in $(ls "$BASE_DIR"); do
    if [ -d "$BASE_DIR/$ano" ]; then
        for mes in $(ls "$BASE_DIR/$ano"); do
            if [ -d "$BASE_DIR/$ano/$mes" ]; then
                processar_mes "$ano" "$mes"
            fi
        done
    fi
done

echo "Processo concluído!" | tee -a "$LOG_FILE"