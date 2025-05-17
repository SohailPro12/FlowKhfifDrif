#!/usr/bin/env bash
# lib/logger.sh — Fonctions de journalisation

# Variables
# Utilisation du répertoire personnel de l'utilisateur pour les logs
HOME_DIR="${HOME:-/home/$(whoami)}"
LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
LOG_FILE="$LOG_DIR/history.log"

# Création du répertoire de logs si nécessaire
mkdir -p "$LOG_DIR" 2>/dev/null || { echo "Impossible de créer le répertoire de logs."; exit 102; }

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
        echo "$timestamp : $user : ERROR  : $message (code $code)" >> "$LOG_FILE"
        echo "$timestamp : $user : ERROR  : $message (code $code)" >&2
    else
        echo "$timestamp : $user : $level  : $message" >> "$LOG_FILE"
        echo "$timestamp : $user : $level  : $message"
    fi
}

# Fonction de nettoyage des logs et fichiers temporaires
clean_logs_and_tmp() {
    echo "Nettoyage des fichiers temporaires et des logs..."

    # Suppression des fichiers temporaires appartenant à l'utilisateur courant dans /tmp/
    if [[ -d /tmp ]]; then
        find /tmp -type f -user "$(whoami)" -exec rm -f {} \; 2>/dev/null || true
        log_message "INFO" "Fichiers temporaires supprimés."
    else
        log_message "ERROR" "Le répertoire /tmp/ n'existe pas." 102
    fi

    # Suppression des fichiers de log dans $LOG_DIR
    if [[ -d "$LOG_DIR" ]]; then
        log_message "INFO" "Réinitialisation du fichier de log."
        cat /dev/null > "$LOG_FILE"
    else
        log_message "ERROR" "Le répertoire de logs spécifié n'existe pas." 102
    fi
}

# Exporter les fonctions
export -f log_message
export -f clean_logs_and_tmp
export LOG_DIR
export LOG_FILE
