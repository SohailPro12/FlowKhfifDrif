#!/usr/bin/env bash
# lib/logger.sh — Gestion des logs avec persistance du chemin

# ====== CONFIGURATION ======
HOME_DIR="${HOME:-/home/$(whoami)}"
CONFIG_FILE="$HOME_DIR/.flowkhfifdrif/logger_config.sh" # Utiliser un nom de fichier plus spécifique

# Valeurs par défaut
DEFAULT_LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/history.log"

# Initialiser les variables avec les valeurs par défaut
LOG_DIR="$DEFAULT_LOG_DIR"
LOG_FILE="$DEFAULT_LOG_FILE"

# Charger la config si elle existe
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Créer le dossier de logs si nécessaire (utilise la valeur chargée ou par défaut)
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "ERROR: Impossible de créer le dossier de logs $LOG_DIR. Vérifiez les permissions." >&2
    exit 102
}

# ====== FONCTIONS ======

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

# Exporter les fonctions et variables nécessaires
export -f log_message
export -f set_log_path
export LOG_DIR
export LOG_FILE
