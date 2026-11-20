# 00 – Áttekintés és munkamódszer

Ez az útmutató végigvezet a féléves feladat **alaprészén (T01–T06, 70 pont)**.
Minden lépést te futtatsz a saját Linux gépeden. Az útmutató megmondja, mit írj be, mire számíts, és röviden azt is, *miért* így csináljuk.

| Adat | Érték |
|---|---|
| Hallgatói azonosító | `CFXLIQ` |
| Feladatváltozat | Track A – Podinfo |
| Telepítési technológia | Kubernetes (kind) + sima manifestek + Kustomize |
| Beadandó | `MST_CFXLIQ_A.zip` |

## Az útmutató fejezetei

| # | Fájl | Mit csinálsz | Ellenőrzések | Becsült idő |
|---|---|---|---|---|
| 01 | [01-kornyezet.md](01-kornyezet.md) | Docker, kubectl, kind telepítése | – | 45–60 perc |
| 02 | [02-telepites.md](02-telepites.md) | Cluster, alkalmazás, elérés, hálózat | T01, T02 (C1, C2) | 60 perc |
| 03 | [03-adatmegorzes.md](03-adatmegorzes.md) | Rekord írása, Pod lecserélése | T03, T04 (C3) | 45 perc |
| 04 | [04-frissites.md](04-frissites.md) | 6.14.1 → 6.17.0 frissítés | T05, T06 (C4) | 45 perc |
| 05 | [05-beadas.md](05-beadas.md) | report.md kitöltése, ZIP | (C5) | 2–3 óra |

Tervezz rá még egy-két óra tartalékot hibakeresésre; ezt a kiírás is kéri.
A haladó részt (T07–T10) az alapfeladat **után** kezdjük el.

## A teljes rendszer egy ábrán

```
 Linux laptop (host)
 ┌──────────────────────────────────────────────────────────────────────┐
 │  terminál: curl ──► 127.0.0.1:9898  (kubectl port-forward)            │
 │                         │                                              │
 │  Docker Engine          ▼                                              │
 │  ┌─────────────── container: mst-control-plane (kind node) ─────────┐ │
 │  │  Kubernetes, namespace "mst"                                     │ │
 │  │                                                                  │ │
 │  │  Service podinfo (ClusterIP, :9898) ──► Pod podinfo-xxxxx        │ │
 │  │                                          ├ init: chown 100:101   │ │
 │  │                                          └ podinfo:6.14.1→6.17.0 │ │
 │  │                                               │ /data            │ │
 │  │  PVC podinfo-data ──► PV (local-path, a node fájlrendszerén)     │ │
 │  └──────────────────────────────────────────────────────────────────┘ │
 └──────────────────────────────────────────────────────────────────────┘
```

## Munkamódszer: hogyan rögzítsd a bizonyítékokat

A pontozás **bizonyíték alapú**. Amit nem rögzítettél, az nem történt meg.
Ezért minden fontos parancsot a `scripts/ev.sh` `ev` függvényével futtass:

```bash
cd ~/MST            # mindig a repó gyökeréből dolgozz
source scripts/ev.sh
ev T01-readyz.txt 'curl -sS -i http://127.0.0.1:9898/readyz'
```

Ez az `evidence/T01-readyz.txt` fájl **végére** írja az időpontot, a parancsot, a teljes kimenetet és a kilépési kódot.
Ha valamit újrafuttatsz, a régi kimenet megmarad. Ez szándékos: a kiírás kéri, hogy a későbbi ellenőrzések ne írják felül a korábbi bizonyítékokat.

Minden új terminálban újra futtasd a `source scripts/ev.sh` parancsot.

**Szabályok, amelyeket végig tarts be:**
1. Soha ne hozd létre újra a tesztrekordot a Pod lecserélése vagy a frissítés után: azzal semmit nem bizonyítanál.
2. Soha ne töröld a PVC-t, és a tesztek alatt ne futtass `kubectl delete -k` vagy `kind delete cluster` parancsot.
3. Ha egy lépés nem úgy sikerül, ahogy vártad, **ne javítsd át a bizonyítékot**. Hagyd benne, írd le a `report.md`-be, mit láttál és hogyan javítottad. Ez részpontot ér.
4. Ha elakadsz, másold be nekem a pontos parancsot és a kimenetét.

## Git: a változások nyomon követése

A repót a laptopodra klónozod (01. fejezet). A fontos pontokon commitolsz, így a git history maga is bizonyíték arra, hogy a frissítés egy konfigurációmódosítás volt, nem kézi beavatkozás.
