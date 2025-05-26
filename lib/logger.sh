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

    # Toujours écrire les logs dans le fichier
    if [[ "$level" == "ERROR" && -n "$code" ]]; then
        echo "$timestamp : $user : ERROR  : $message (code $code)" >> "$LOG_FILE"
    else
        echo "$timestamp : $user : $level  : $message" >> "$LOG_FILE"
    fi

    # N'afficher dans le terminal que les messages INFO
    if [[ "$level" == "INFO" ]]; then
        echo "$timestamp : $user : $level  : $message"
    fi
}

# Exporter les fonctions
export -f log_message
export LOG_DIR
export LOG_FILE
