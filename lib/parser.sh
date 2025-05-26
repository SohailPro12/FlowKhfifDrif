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

  # --- COMMANDES GIT LOCAL ---

  # 1) init <repo> - Initialisation d'un dépôt
  if [[ "$INPUT" =~ ^init[[:space:]]+([A-Za-z0-9._-]+)([[:space:]]+(true|false))?([[:space:]]+([^[:space:]]+))?$ ]]; then
    log_message "INFO" "Initialisation du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "init_remote_repo ${BASH_REMATCH[1]} ${BASH_REMATCH[3]:-false} ${BASH_REMATCH[5]:-.}"
    return 0
  fi

  # 2) clone <url> [dest] - Clonage d'un dépôt
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

  # 3) add - Ajout de fichiers
  if [[ "$INPUT" =~ ^add$ ]]; then
    log_message "INFO" "Ajout de tous les fichiers modifiés" >&2
    echo "git add ."
    return 0
  fi

  # 4) commit <msg> - Commit avec message (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^commit[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local MSG="${BASH_REMATCH[1]}"
    log_message "INFO" "Commit avec message \"$MSG\"" >&2
    echo "git commit -m \"$MSG\""
    return 0
  fi

  # 5) add-commit <msg> - Ajout et commit combinés (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^add-commit[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local MSG="${BASH_REMATCH[1]}"
    log_message "INFO" "Ajout et commit avec message \"$MSG\"" >&2
    echo "git add . && git commit -m \"$MSG\""
    return 0
  fi

  # 6) push-<branch> <msg> - Push avec add, commit et message (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "Push vers la branche $BR avec message de commit" >&2
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 7) push-<branch> - Push sans add/commit
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    log_message "INFO" "Push vers la branche $BR" >&2
    echo "git push origin $BR"
    return 0
  fi

  # 8) branch-<name> - Création d'une branche
  if [[ "$INPUT" =~ ^branch-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création de la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 9) checkout-<branch> - Basculement vers une branche
  if [[ "$INPUT" =~ ^checkout-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Basculement vers la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 10) status - Affichage du statut Git
  if [[ "$INPUT" =~ ^status$ ]]; then
    log_message "INFO" "Affichage du statut Git" >&2
    echo "git status"
    return 0
  fi

  # 11) log - Affichage du dernier commit
  if [[ "$INPUT" =~ ^log$ ]]; then
    log_message "INFO" "Affichage du dernier commit" >&2
    echo "git log -1 --oneline"
    return 0
  fi

  # 12) pull-<branch> - Pull depuis une branche
  if [[ "$INPUT" =~ ^pull-([A-Za-z0-9._-]+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    log_message "INFO" "Pull depuis origin/$BR" >&2
    echo "git pull origin $BR"
    return 0
  fi

  # 13) push-<branch>-test - Push avec exécution des tests
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)-test$ ]]; then
    log_message "INFO" "Push vers la branche ${BASH_REMATCH[1]} avec exécution des tests" >&2
    echo "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # --- COMMANDES DE DÉPENDANCES ET NETTOYAGE ---

  # 14) install-<library> - Installation d'une bibliothèque
  if [[ "$INPUT" =~ ^install-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Installation de la bibliothèque ${BASH_REMATCH[1]}" >&2
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 15) clean - Nettoyage des logs et fichiers temporaires
  if [[ "$INPUT" =~ ^clean$ ]]; then
    log_message "INFO" "Nettoyage des logs et fichiers temporaires" >&2
    echo "clean_logs_and_tmp"
    return 0
  fi

  # --- COMMANDES GITHUB REMOTE ---

  # 16) remote-<repo> - Création d'un dépôt distant
  if [[ "$INPUT" =~ ^remote-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi

  # 17) board-<repo> - Configuration d'un tableau
  if [[ "$INPUT" =~ ^board-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Configuration du tableau ${BASH_REMATCH[1]}" >&2
    echo "create_board ${BASH_REMATCH[1]}"
    return 0
  fi

  # 18) issue-<repo> <title> - Création d'une issue (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^issue-([A-Za-z0-9._-]+)[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    log_message "INFO" "Création d'une issue \"${BASH_REMATCH[2]}\" pour ${BASH_REMATCH[1]}" >&2
    echo "create_github_issue \"${BASH_REMATCH[2]}\" ${BASH_REMATCH[1]}"
    return 0
  fi

  # 19) assign-<user>-<repo>-<num> - Attribution d'une issue
  if [[ "$INPUT" =~ ^assign-([A-Za-z0-9._-]+)-([A-Za-z0-9._-]+)-([0-9]+)$ ]]; then
    log_message "INFO" "Attribution de l'utilisateur ${BASH_REMATCH[1]} à l'issue #${BASH_REMATCH[3]} dans ${BASH_REMATCH[2]}" >&2
    echo "assign_github_issue ${BASH_REMATCH[3]} ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    return 0
  fi

  # Commande non reconnue
  log_message "ERROR" "Commande non reconnue: $INPUT" 100 >&2
  return 1
}
