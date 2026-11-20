# evidence/

Ide kerülnek a **valódi, saját gépen futtatott** parancsok kimenetei.
Minden fájlt a `scripts/ev.sh` `ev` függvénye ír, és ez mindig hozzáfűz, nem írja felül a korábbi tartalmat.

Elnevezés: `<ellenőrzés-ID>-<rövid-leírás>.txt`, például `T03-store-post.txt`.

| Fájl (minta) | Melyik lépés írja |
|---|---|
| `ENV-*.txt` | 01 – környezet, eszközverziók |
| `C1-*.txt`, `T01-*`, `T02-*`, `C2-*` | 02 – telepítés, elérés, hálózat |
| `T03-*`, `T04-*` | 03 – adatírás, példánycsere |
| `T05-*`, `T06-*` | 04 – verziófrissítés |

Az `expected`/`readback` fájlok az összehasonlított bájtokat tartalmazzák.
