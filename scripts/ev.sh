# shellcheck shell=bash
# Parancskimenet rögzítése az evidence/ mappába.
#
# Betöltés a projekt gyökeréből:  source scripts/ev.sh
# Használat:                      ev <fájlnév> '<parancs>'
# Példa:                          ev T01-readyz.txt 'curl -sS -i http://127.0.0.1:9898/readyz'
#
# Az evidence/<fájlnév> végére írja (nem írja felül) az időpontot, a parancsot,
# a teljes kimenetet (stdout + stderr) és a kilépési kódot.

ev() {
  if [ "$#" -lt 2 ]; then
    echo "használat: ev <evidence-fájlnév> '<parancs>'" >&2
    return 2
  fi
  local root file
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$root" ] || [ ! -f "$root/deployment/kustomization.yaml" ]; then
    root="$(pwd)"
    if [ ! -f "$root/deployment/kustomization.yaml" ]; then
      echo "HIBA: a projekt gyökeréből futtasd (ahol a deployment/ mappa van)" >&2
      return 2
    fi
  fi
  file="$1"
  shift
  mkdir -p "$root/evidence"
  {
    printf '### %s  (host: %s)\n' "$(date --iso-8601=seconds)" "$(hostname)"
    printf '$ %s\n' "$*"
    (cd "$root" && bash -c "$*")
    printf '[exit code: %s]\n\n' "$?"
  } 2>&1 | tee -a "$root/evidence/$file"
}
