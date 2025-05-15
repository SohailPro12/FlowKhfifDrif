#!/bin/bash
# Variables
log_dir="/var/log/FlowKhfifDrif/"
log_file="$log_dir/history.log"
set -euo pipefail
# Création du répertoire de logs si nécessaire
mkdir -p "$log_dir" || log_message "ERROR" "Impossible de créer le répertoire de logs." 102 
# Fonction de journalisation
log_message() {
    local level="$1"
    local message="$2"
    local code="${3:-}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    local user
    user=$(whoami)

    if [[ "$level" == "ERROR" && -n "$code" ]]; then
        echo "$timestamp : $user : ERROR  : $message (code $code)" | tee -a "$log_file"
    else
        echo "$timestamp : $user : $level  : $message" | tee -a "$log_file"
    fi
}
# Fonction d'affichage de l'aide
function show_help() {
    cd ..
    if [[ -f "$log_dir/docs/help.txt" ]]; then
        log_message "INFOS" "Affichage de l'aide utilisateur depuis docs/help.txt"
        cat $log_dir/docs/help.txt    
    else
        log_message "ERRER" "Fichier d'aide introuvable." 102
    fi
}

clean_logs_and_tmp() {
    echo "Nettoyage des fichiers temporaires et des logs..."

    # Suppression des fichiers temporaires appartenant à l'utilisateur courant dans /tmp/
    if [[ -d /tmp ]]; then
        find /tmp -type f -user "$(whoami)" -exec rm -f {} \;
        log_message "INFO" "Fichiers temporaires supprimés."
    else
        log_message "ERROR" "Le répertoire /tmp/ n'existe pas." 102
    fi

    # Suppression des fichiers de log dans $LOG_DIR
    if [[ -n "${log_dir:-}" && -d "$log_dir" ]]; then
        log_message "INFO" "Fichiers de log supprimés."
        rm $log_file
        touch $log_file
    else
        log_message "ERROR" "Le répertoire de logs spécifié n'existe pas ou LOG_DIR n'est pas défini." 102
    fi
}


# Redirection des sorties vers le fichier de log
exec > >(tee -a "$log_file") 2>&1 || log_message "ERROR" "Impossible de créer le répertoire de logs." 102
