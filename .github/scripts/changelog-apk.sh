#!/usr/bin/env bash
# Gera o changelog (Markdown) de um release apk-dev a partir dos Conventional
# Commits entre o release anterior e o tip. Uso:
#   changelog-apk.sh [TIP]            (TIP padrão: HEAD)
# Env opcional: TAG_PATTERN (padrão apk-dev-*), CURRENT_TAG (ignorada na busca),
#               LINEAR_URL (padrão https://linear.app/felpszip/issue).
# Imprime as seções Novidades / Correções / Outros em stdout; o chamador
# acrescenta a seção Build.
set -euo pipefail

tip="${1:-HEAD}"
pattern="${TAG_PATTERN:-apk-dev-*}"
current="${CURRENT_TAG:-}"
linear="${LINEAR_URL:-https://linear.app/felpszip/issue}"
bump_re='^chore\(release\): bump .*\[skip ci\]'

# 1) Ponto de partida: tag apk-dev-* mais recente (por versão) que seja
#    ancestral do tip. Vale quando a tag aponta para o bump na stage
#    (gh release create --target, L2S-82). CURRENT_TAG é ignorada (rerun).
base=""
while IFS= read -r t; do
  [ -z "$t" ] && continue
  [ "$t" = "$current" ] && continue
  if git merge-base --is-ancestor "$t^{commit}" "$tip" 2>/dev/null; then
    base="$t"; break
  fi
done < <(git tag -l "$pattern" --sort=-v:refname)

# 2) Fallback: último bump de release no histórico do tip (tags antigas
#    apontam para main). O bump é commitado logo após cada build e este script
#    roda antes do bump da build atual, então ele marca o release anterior.
if [ -z "$base" ]; then
  base="$(git log --first-parent --format=%H -E --grep="$bump_re" -n1 "$tip" || true)"
fi

# 3) Sem nenhum dos dois: histórico completo até o tip.
range="$tip"; [ -n "$base" ] && range="${base}..${tip}"
echo "changelog: range=${range}" >&2

# Guard: há algum commit além de bumps desde o release anterior?
nonbump="$(git log --no-merges --format=%s "$range" | grep -cvE "$bump_re" || true)"
if [ "${nonbump:-0}" -gt 0 ]; then has_changes=true; else has_changes=false; fi
echo "changelog: commits_sem_bump=${nonbump:-0} has_changes=${has_changes}" >&2
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  { echo "has_changes=${has_changes}"; echo "base=${base}"; } >> "$GITHUB_OUTPUT"
fi

feat=(); fix=(); other=()
while IFS=$'\x1f' read -r sha subject body; do
  sha="${sha#"${sha%%[![:space:]]*}"}"
  [ -z "$sha" ] && continue
  [[ "$subject" =~ $bump_re ]] && continue
  type="" ; desc="$subject"
  if [[ "$subject" =~ ^([a-zA-Z]+)(\([^\)]*\))?(!)?:[[:space:]]*(.*)$ ]]; then
    type="${BASH_REMATCH[1],,}"; desc="${BASH_REMATCH[4]}"
  fi
  issues="$(printf '%s\n%s\n' "$subject" "$body" | grep -oE 'L2S-[0-9]+' | sort -u -t- -k2,2n || true)"
  links=""
  for i in $issues; do links+=" [${i}](${linear}/${i})"; done
  line="- ${desc} (\`${sha:0:7}\`)${links}"
  case "$type" in
    feat) feat+=("$line") ;;
    fix) fix+=("$line") ;;
    refactor|perf|chore) other+=("$line") ;;
    *) : ;;  # ci/docs/test/style/build e commits fora do padrão ficam de fora
  esac
done < <(git log --no-merges --reverse --format='%H%x1f%s%x1f%b%x1e' "$range" | tr '\n\036' ' \n')

if [ ${#feat[@]} -eq 0 ] && [ ${#fix[@]} -eq 0 ] && [ ${#other[@]} -eq 0 ]; then
  echo "Sem mudanças funcionais"
  exit 0
fi
section() { local t="$1"; shift; [ $# -eq 0 ] && return; printf '## %s\n\n' "$t"; printf '%s\n' "$@"; echo; }
section "Novidades" "${feat[@]}"
section "Correções" "${fix[@]}"
section "Outros" "${other[@]}"
