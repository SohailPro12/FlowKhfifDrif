#!/usr/bin/env bash
# lib/parser.sh — translate natural → commands or function calls
# pthe de gestion de logger
source /var/log/FlowKhfifDrif/lib/logger.sh
parse_natural() {
  local INPUT="$*"

  # 1) init via GitHub module
  if [[ "$INPUT" =~ ^init[[:space:]]+([A-Za-z0-9._-]+)([[:space:]]+(true|false))?([[:space:]]+([^[:space:]]+))?$ ]]; then
    log_message "INFO" "init_remote_repo ${BASH_REMATCH[1]} ${BASH_REMATCH[3]:-false} ${BASH_REMATCH[5]:-.}"
    return 0
  fi

  # 2) clone <url> [dest]
  if [[ "$INPUT" =~ ^clone[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]]+))?$ ]]; then
    local URL="${BASH_REMATCH[1]}"
    local D="${BASH_REMATCH[3]}"
    if [[ -n "$D" ]]; then
      log_message "INFO" "git clone $URL $D"
    else
      log_message "INFO" "git clone $URL"
    fi
    return 0
  fi

  # 3) push into <branch> with commit <msg>  (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+with[[:space:]]+commit[[:space:]]+(.+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 4) create a new branch called <name>
  if [[ "$INPUT" =~ ^create[[:space:]]+a[[:space:]]+new[[:space:]]+branch[[:space:]]+called[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 5) switch to branch <name>
  if [[ "$INPUT" =~ ^switch[[:space:]]+to[[:space:]]+branch[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 6) show status
  if [[ "$INPUT" =~ ^show[[:space:]]+status$ ]]; then
    log_message "INFO" "git status"
    return 0
  fi

  # 7) show latest commit
  if [[ "$INPUT" =~ ^show[[:space:]]+latest[[:space:]]+commit$ ]]; then
    log_message "INFO" "git log -1 --oneline"
    return 0
  fi

  # 8) pull from origin [branch <name>]
  if [[ "$INPUT" =~ ^pull[[:space:]]+from[[:space:]]+origin([[:space:]]+branch[[:space:]]+([A-Za-z0-9._-]+))?$ ]]; then
    local BR="${BASH_REMATCH[2]:-main}"
    log_message "INFO" "git pull origin $BR"
    return 0
  fi


  # 9) push into <branch> with tests
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+with[[:space:]]+tests$ ]]; then
    log_message "INFO" "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # 10) install library <name>
  if [[ "$INPUT" =~ ^i[[:space:]]+want[[:space:]]+the[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+library$ ]]; then
    log_message "INFO" "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

   # 11) clean logs and tmp files
  if [[ "$INPUT" =~ ^clean[[:space:]]+logs[[:space:]]+and[[:space:]]+tmp[[:space:]]+files$ ]]; then
    clean_logs_and_tmp
    return 0
  fi

  # GitHub commands (fonctions dans github.sh)
  if [[ "$INPUT" =~ ^create[[:space:]]+remote[[:space:]]+repo[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$INPUT" =~ ^setup[[:space:]]+board[[:space:]]+and[[:space:]]+issues[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "setup_board_and_issues ${BASH_REMATCH[1]}"
    return 0
  fi


  if [[ "$INPUT" =~ ^create[[:space:]]+issue[[:space:]]+\"([^\"]+)\"[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    # create issue "<titre>" <repo>
  # 🛠️ ➤ À implémenter par le développeur B(Fatima) :
  #     Ajouter dans github.sh une fonction :
  #     create_github_issue "<titre>" <repo>
  #     Elle doit créer une issue sur GitHub via API REST.
    echo "create_github_issue \"${BASH_REMATCH[1]}\" ${BASH_REMATCH[2]}"
    return 0
  fi

  if [[ "$INPUT" =~ ^assign[[:space:]]+user[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+to[[:space:]]+issue[[:space:]]+#([0-9]+)[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
  # assign user <utilisateur> to issue #<num> <repo>
  # 🛠️ ➤ À implémenter par le développeur B(Fatima) :
  #     Ajouter dans github.sh une fonction :
  #     assign_github_issue <num> <user> <repo>
  #     Elle doit utiliser l'API GitHub pour assigner l'utilisateur.
    echo "assign_github_issue ${BASH_REMATCH[2]} ${BASH_REMATCH[1]} ${BASH_REMATCH[3]}"
    return 0
  fi

  # rien de reconnu
  echo "echo 'Commande non reconnue.'" >&2
  exit 100
}
