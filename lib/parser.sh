#!/usr/bin/env bash
# lib/parser.sh — translate natural → commands or function calls

# Importer le logger
# Utilisation du répertoire personnel de l'utilisateur pour les logs
if [[ -z "$LOG_DIR" ]]; then
  HOME_DIR="${HOME:-/home/$(whoami)}"
  LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
fi

# Charger le logger s'il n'est pas déjà chargé
if ! type log_message &>/dev/null; then
  source "$LOG_DIR/../lib/logger.sh"
fi

parse_natural() {
  local INPUT="$*"

  # 1) init via GitHub module
  if [[ "$INPUT" =~ ^init[[:space:]]+([A-Za-z0-9._-]+)([[:space:]]+(true|false))?([[:space:]]+([^[:space:]]+))?$ ]]; then
    log_message "INFO" "Initialisation du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "init_remote_repo ${BASH_REMATCH[1]} ${BASH_REMATCH[3]:-false} ${BASH_REMATCH[5]:-.}"
    return 0
  fi

  # 2) clone <url> [dest]
  if [[ "$INPUT" =~ ^clone[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]]+))?$ ]]; then
    local URL="${BASH_REMATCH[1]}"
    local D="${BASH_REMATCH[3]}"
    if [[ -n "$D" ]]; then
      log_message "INFO" "Clonage du dépôt $URL vers $D" >&2
      echo "git clone $URL $D"
    else
      log_message "INFO" "Clonage du dépôt $URL" >&2
      echo "git clone $URL"
    fi
    return 0
  fi

  # 3) push into <branch> with commit <msg>  (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+with[[:space:]]+commit[[:space:]]+(.+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "Push vers la branche $BR avec message de commit" >&2
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 4) create a new branch called <n>
  if [[ "$INPUT" =~ ^create[[:space:]]+a[[:space:]]+new[[:space:]]+branch[[:space:]]+called[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création de la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 5) switch to branch <n>
  if [[ "$INPUT" =~ ^switch[[:space:]]+to[[:space:]]+branch[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Basculement vers la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 6) show status
  if [[ "$INPUT" =~ ^show[[:space:]]+status$ ]]; then
    log_message "INFO" "Affichage du statut Git" >&2
    echo "git status"
    return 0
  fi

  # 7) show latest commit
  if [[ "$INPUT" =~ ^show[[:space:]]+latest[[:space:]]+commit$ ]]; then
    log_message "INFO" "Affichage du dernier commit" >&2
    echo "git log -1 --oneline"
    return 0
  fi

  # 8) pull from origin [branch <n>]
  if [[ "$INPUT" =~ ^pull[[:space:]]+from[[:space:]]+origin([[:space:]]+branch[[:space:]]+([A-Za-z0-9._-]+))?$ ]]; then
    local BR="${BASH_REMATCH[2]:-main}"
    log_message "INFO" "Pull depuis origin/$BR" >&2
    echo "git pull origin $BR"
    return 0
  fi

  # 9) push into <branch> with tests
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+with[[:space:]]+tests$ ]]; then
    log_message "INFO" "Push vers la branche ${BASH_REMATCH[1]} avec exécution des tests" >&2
    echo "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # 10) install library <n>
  if [[ "$INPUT" =~ ^i[[:space:]]+want[[:space:]]+the[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+library$ ]]; then
    log_message "INFO" "Installation de la bibliothèque ${BASH_REMATCH[1]}" >&2
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 11) clean logs and tmp files
  if [[ "$INPUT" =~ ^clean[[:space:]]+logs[[:space:]]+and[[:space:]]+tmp[[:space:]]+files$ ]]; then
    log_message "INFO" "Nettoyage des logs et fichiers temporaires" >&2
    echo "clean_logs_and_tmp"
    return 0
  fi

  # GitHub commands (fonctions dans github.sh)
  if [[ "$INPUT" =~ ^create[[:space:]]+remote[[:space:]]+repo[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi
  
  if [[ "$INPUT" =~ ^setup[[:space:]]+board[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Configuration du tableau pour ${BASH_REMATCH[1]}" >&2
    echo "create_board ${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$INPUT" =~ ^create[[:space:]]+issue[[:space:]]+\"([^\"]+)\"[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création d'une issue \"${BASH_REMATCH[1]}\" pour ${BASH_REMATCH[2]}" >&2
    echo "create_github_issue \"${BASH_REMATCH[1]}\" ${BASH_REMATCH[2]}"
    return 0
  fi

  if [[ "$INPUT" =~ ^assign[[:space:]]+user[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+to[[:space:]]+issue[[:space:]]+#([0-9]+)[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Attribution de l'utilisateur ${BASH_REMATCH[1]} à l'issue #${BASH_REMATCH[2]} dans ${BASH_REMATCH[3]}" >&2
    echo "assign_github_issue ${BASH_REMATCH[2]} ${BASH_REMATCH[1]} ${BASH_REMATCH[3]}"
    return 0
  fi

  # Commande non reconnue
  log_message "ERROR" "Commande non reconnue: $INPUT" 100 >&2
  return 1
}
