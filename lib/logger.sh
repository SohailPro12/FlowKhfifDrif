#!/bin/bash
# Variables
log_dir="flowkhfifdrif/"
log_file="$log_dir/history.log"
set -euo pipefail

# Fonction de gestion des erreurs
function handle_error() {
    local exit_code=$1
    local message=$2
    echo "Erreur ($exit_code): $message" >&2
    exit $exit_code
}
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
        echo "$timestamp : $user : ERROR  : $message (code $code)" >> "$log_file"
    else
        echo "$timestamp : $user : $level  : $message" >> "$log_file"
    fi
}
# Fonction d'affichage de l'aide
function show_help() {
    cd ..
    if [[ -f "docs/help.txt" ]]; then
        log_message "INFOS" "Affichage de l'aide utilisateur depuis docs/help.txt"
        cat docs/help.txt    
    else
        log_message "ERRER" "Fichier d'aide introuvable." 102
    fi
}
# Création du répertoire de logs si nécessaire
mkdir -p "$log_dir" || log_message "ERROR" "Impossible de créer le répertoire de logs." 102 

# Redirection des sorties vers le fichier de log
exec > >(tee -a "$log_file") 2>&1 || handle_error 102 "Impossible de créer le répertoire de logs."
# Analyse des options
if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                LOG_DIR="$2"
                LOG_FILE="$LOG_DIR/history.log"
                mkdir -p "$LOG_DIR" || log_message "ERRER" "Impossible de créer le répertoire de logs spécifié." 101 
                shift 2
            else
                handle_error 102 "L'option -l nécessite un argument (dossier de logs)."
            fi
            ;;
        -*)
            log_message "ERRER" "Option inconnue : $1" 103
            handle_error 103 "Option inconnue : $1" 
            ;;
        *)
            echo "Argument non reconnu : $1"
            shift
            ;;
    esac
fi