#!/usr/bin/env bash
# Instala o OmniRoute e (opcionalmente) aponta o Claude Code para ele.
#
#   ./setup-omniroute.sh              instala e sobe o gateway
#   ./setup-omniroute.sh --claude     idem + escreve ~/.claude/settings.json
#   ./setup-omniroute.sh --restore    desfaz a config do Claude Code
#
# Requer Node >=22.22.2 <23 ou >=24 <27.

set -euo pipefail

SETTINGS="${HOME}/.claude/settings.json"
BACKUP="${SETTINGS}.antes-do-omniroute"
PORT=20128

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

check_node() {
  command -v node >/dev/null 2>&1 || die "Node nao encontrado. Instale o Node 22 LTS."
  node -e '
    const [maj, min, pat] = process.versions.node.split(".").map(Number);
    const ok =
      (maj === 22 && (min > 22 || (min === 22 && pat >= 2))) ||
      (maj >= 24 && maj < 27);
    if (!ok) {
      console.error("Node " + process.versions.node + " nao serve. Precisa de >=22.22.2 <23 ou >=24 <27.");
      process.exit(1);
    }
  ' || die "Troque a versao do Node (nvm install 22 && nvm use 22) e rode de novo."
  info "Node $(node -v) ok."
}

restore_claude() {
  [ -f "$BACKUP" ] || die "Nenhum backup em $BACKUP."
  mv "$BACKUP" "$SETTINGS"
  info "settings.json restaurado. Claude Code voltou para a conta Anthropic."
  exit 0
}

configure_claude() {
  local key="${OMNIROUTE_KEY:-}"
  if [ -z "$key" ]; then
    printf 'Cole a chave do painel (Dashboard -> Endpoints): '
    read -r key
  fi
  [ -n "$key" ] || die "Chave vazia. Pegue em http://localhost:${PORT} -> Endpoints."

  mkdir -p "$(dirname "$SETTINGS")"
  if [ -f "$SETTINGS" ] && [ ! -f "$BACKUP" ]; then
    cp "$SETTINGS" "$BACKUP"
    info "Backup salvo em $BACKUP"
  fi

  # Merge preservando o que ja existe no settings.json.
  SETTINGS_PATH="$SETTINGS" OMNI_KEY="$key" OMNI_PORT="$PORT" node -e '
    const fs = require("fs");
    const p = process.env.SETTINGS_PATH;
    let cfg = {};
    if (fs.existsSync(p)) {
      try { cfg = JSON.parse(fs.readFileSync(p, "utf8")); }
      catch (e) { console.error("settings.json invalido, abortando: " + e.message); process.exit(1); }
    }
    cfg.env = cfg.env || {};
    // Sem /v1 aqui: o Claude Code usa a raiz do gateway Anthropic.
    cfg.env.ANTHROPIC_BASE_URL = "http://localhost:" + process.env.OMNI_PORT;
    cfg.env.ANTHROPIC_AUTH_TOKEN = process.env.OMNI_KEY;
    fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n");
  '
  info "Claude Code apontado para http://localhost:${PORT}"
  info 'Teste com: claude "diga ola"'
}

main() {
  case "${1:-}" in
    --restore) restore_claude ;;
  esac

  check_node

  info "Instalando o omniroute (global)..."
  npm install -g omniroute

  if [ "${1:-}" = "--claude" ]; then
    warn "Suba o gateway em outro terminal (omniroute), conecte um provedor no painel"
    warn "e pegue a chave em Dashboard -> Endpoints antes de continuar."
    configure_claude
    exit 0
  fi

  info "Subindo o gateway. Painel: http://localhost:${PORT}"
  info "Depois de conectar um provedor, rode: ./setup-omniroute.sh --claude"
  exec omniroute
}

main "$@"
