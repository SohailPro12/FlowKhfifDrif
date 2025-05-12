#!/usr/bin/env bash
# lib/parser.sh — translate natural commands into shell commands

parse_natural() {
  local INPUT="$*"

  # 1) init <dir>
  if [[ "$INPUT" =~ ^init[[:space:]]+([a-zA-Z0-9._-]+)$ ]]; then
    echo "git init ${BASH_REMATCH[1]}"
    return 0
  fi

  # 2) clone <url> [dest]
  if [[ "$INPUT" =~ ^clone[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]]+))?$ ]]; then
    local URL="${BASH_REMATCH[1]}"
    local DEST="${BASH_REMATCH[3]}"
    if [[ -n "$DEST" ]]; then
      echo "git clone $URL $DEST"
    else
      echo "git clone $URL"
    fi
    return 0
  fi

  # 3) push into <branch> with commit "<msg>"
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([a-zA-Z0-9._-]+)[[:space:]]+with[[:space:]]+commit[[:space:]]+\"([^\"]+)\"$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 4) create a new branch called <name>
  if [[ "$INPUT" =~ ^create[[:space:]]+a[[:space:]]+new[[:space:]]+branch[[:space:]]+called[[:space:]]+([a-zA-Z0-9._-]+)$ ]]; then
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 5) switch to branch <name>
  if [[ "$INPUT" =~ ^switch[[:space:]]+to[[:space:]]+branch[[:space:]]+([a-zA-Z0-9._-]+)$ ]]; then
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 6) show status
  if [[ "$INPUT" =~ ^show[[:space:]]+status$ ]]; then
    echo "git status"
    return 0
  fi

  # 7) show latest commit
  if [[ "$INPUT" =~ ^show[[:space:]]+latest[[:space:]]+commit$ ]]; then
    echo "git log -1 --oneline"
    return 0
  fi

  # 8) pull from origin
  if [[ "$INPUT" =~ ^pull[[:space:]]+from[[:space:]]+origin$ ]]; then
    echo "git pull origin"
    return 0
  fi

  # 9) push into <branch> with tests
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([a-zA-Z0-9._-]+)[[:space:]]+with[[:space:]]+tests$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    echo "git add . && git commit -m 'auto tests' && git push origin $BR && cd Test && npm test"
    return 0
  fi

  # 10) install library <name>
  if [[ "$INPUT" =~ ^i[[:space:]]+want[[:space:]]+the[[:space:]]+([a-zA-Z0-9._-]+)[[:space:]]+library$ ]]; then
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 11) clean logs and tmp files
  if [[ "$INPUT" =~ ^clean[[:space:]]+logs[[:space:]]+and[[:space:]]+tmp[[:space:]]+files$ ]]; then
    # LOG_DIR is set by the main script
    echo "rm -rf /tmp/* && rm -f \"\$LOG_DIR\"/*.log"
    return 0
  fi

  # If no pattern matched
  echo "echo 'Commande non reconnue (parser natif)'" >&2
  exit 100
}
