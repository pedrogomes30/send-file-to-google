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
    local cnpj_path=$1
    local zip_file=$2

    echo "Compactando o conteúdo de $cnpj_path para $zip_file..." | tee -a "$LOG_FILE"

    if [ -d "$cnpj_path" ]; then
        if [ "$(ls -A "$cnpj_path")" ]; then
            (cd "$cnpj_path" && zip -r "$zip_file" .) >> "$LOG_FILE" 2>&1
        else
            echo "Diretório $cnpj_path está vazio. Nada para compactar." | tee -a "$LOG_FILE"
            return 1
        fi
    else
        echo "Diretório $cnpj_path não encontrado." | tee -a "$LOG_FILE"
        return 1
    fi
}

enviar_para_google_drive() {
    local zip_file=$1
    local remote_dest=$2

    echo "Enviando $zip_file para $remote_dest no Google Drive..." | tee -a "$LOG_FILE"
    rclone copy "$zip_file" "$remote_dest" --drive-server-side-across-configs -v >> "$LOG_FILE" 2>&1

    echo "Removendo arquivo local $zip_file..." | tee -a "$LOG_FILE"
    rm -f "$zip_file"
}

compactar_e_enviar() {
    local ano=$1
    local mes=$2
    local cnpj=$3
    local cnpj_path="$BASE_DIR/$ano/$mes/$cnpj"
    local zip_file="/tmp/${cnpj}.zip"
    local remote_dest="$RCLONE_REMOTE:$REMOTE_PATH/$ano/$mes"

    if [ -d "$cnpj_path" ]; then
        compactar "$cnpj_path" "$zip_file"
        
        if [ -f "$zip_file" ]; then
            echo "Arquivo compactado gerado com sucesso: $zip_file" | tee -a "$LOG_FILE"
        else
            echo "Falha ao gerar o arquivo compactado: $zip_file" | tee -a "$LOG_FILE"
        fi

        enviar_para_google_drive "$zip_file" "$remote_dest"
    else
        echo "Pasta $cnpj_path não encontrada, pulando..." | tee -a "$LOG_FILE"
    fi
}

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