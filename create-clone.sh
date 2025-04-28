#!/bin/bash

BASE_DIR="/var/www/html/xml"
RCLONE_REMOTE="gdrive-sa"
REMOTE_PATH="xml/woo_pdv"
LOG_FILE="/var/log/rclone-woo-pdv.log"

compactar_e_enviar() {
    local ano=$1
    local mes=$2
    local cnpj=$3
    local cnpj_path="$BASE_DIR/$ano/$mes/$cnpj"
    local zip_file="/tmp/${cnpj}.zip"
    local remote_dest="$RCLONE_REMOTE:$REMOTE_PATH/$ano/$mes"

    if [ -d "$cnpj_path" ]; then
        echo "Compactando $cnpj_path..." | tee -a "$LOG_FILE"
        zip -r "$zip_file" "$cnpj_path" >> "$LOG_FILE" 2>&1

        echo "Enviando $zip_file para $remote_dest no Google Drive..." | tee -a "$LOG_FILE"
        rclone copy "$zip_file" "$remote_dest" --drive-server-side-across-configs -v >> "$LOG_FILE" 2>&1

        echo "Removendo arquivo local $zip_file..." | tee -a "$LOG_FILE"
        rm -f "$zip_file"
    else
        echo "Pasta $cnpj_path não encontrada, pulando..." | tee -a "$LOG_FILE"
    fi
}

# Itera sobre os anos, meses e CNPJs
for ano in $(ls "$BASE_DIR"); do
    if [ -d "$BASE_DIR/$ano" ]; then
        for mes in $(ls "$BASE_DIR/$ano"); do
            if [ -d "$BASE_DIR/$ano/$mes" ]; then
                for cnpj in $(ls "$BASE_DIR/$ano/$mes"); do
                    if [ -d "$BASE_DIR/$ano/$mes/$cnpj" ]; then
                        compactar_e_enviar "$ano" "$mes" "$cnpj"
                    fi
                done
            fi
        done
    fi
done

echo "Processo concluído!" | tee -a "$LOG_FILE"