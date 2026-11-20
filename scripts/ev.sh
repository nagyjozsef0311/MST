# shellcheck shell=bash
# Bizonyítékrögzítő segédfüggvény. Betöltés (a repó gyökeréből):
#
#   source scripts/ev.sh
#
# Használat:
#
#   ev T01-readyz.txt 'curl -sS -i http://127.0.0.1:9898/readyz'
#
# Mit csinál: az evidence/<fájl> VÉGÉRE írja (nem írja felül!) az időbélyeget,
# a pontos parancsot, a parancs teljes kimenetét (stdout + stderr) és a
# kilépési kódot, közben a képernyőre is kiírja.
#
# A parancsot egyetlen, aposztrófok közé tett szövegként add meg; így a
# csövek (|) és átirányítások (>) is a rögzített parancs részei maradnak.
# A shell változókat (pl. $HASH) `export`-tal tedd elérhetővé.

ev() {
  if [ "$#" -lt 2 ]; then
    echo "használat: ev <evidence-fájlnév> '<parancs>'" >&2
    return 2
  fi
  local root file
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$root" ] || [ ! -f "$root/deployment/kustomization.yaml" ]; then
    echo "HIBA: nem az MST repóban vagy (most: $PWD). Futtasd: cd ~/MST" >&2
    return 2
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
