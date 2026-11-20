# MST féléves feladat – Track A: Podinfo életciklusa Kubernetesen

| | |
|---|---|
| Hallgató | `CFXLIQ` |
| Feladatváltozat | **A – Podinfo** (`stefanprodan/podinfo:6.14.1` → `6.17.0`) |
| Telepítési technológia | **Kubernetes** (helyi `kind` cluster), sima manifestek + Kustomize |
| Beszámoló | [report.md](report.md) |
| Lépésenkénti útmutató | [docs/00-attekintes.md](docs/00-attekintes.md) |

## Könyvtárszerkezet

```
.
├── README.md              # ez a fájl: előfeltételek, indítás, ellenőrzés, frissítés, takarítás
├── report.md              # műszaki beszámoló
├── deployment/            # a megismételhető telepítés forrásai
│   ├── kind-config.yaml   #   helyi, egy node-os cluster leírása
│   ├── kustomization.yaml #   belépési pont: kubectl apply -k deployment/
│   ├── namespace.yaml     #   "mst" névtér
│   ├── pvc.yaml           #   podinfo-data PVC (1Gi, RWO, alapértelmezett StorageClass)
│   ├── deployment.yaml    #   podinfo Deployment (1 replica, Recreate, init container, IMAGE TAG)
│   └── service.yaml       #   belső ClusterIP Service, 9898/TCP
├── scripts/ev.sh          # bizonyítékrögzítő segédfüggvény
├── testdata/record.txt    # a tesztrekord (az elvárt bájtok)
├── docs/                  # lépésenkénti útmutató elmélettel
└── evidence/              # a ténylegesen futtatott parancsok kimenetei
```

## Előfeltételek

Linux (x86_64), a következő eszközökkel. A pontos, ténylegesen használt verziók az `evidence/ENV-tools.txt` fájlban vannak.

- Docker Engine
- `kind`
- `kubectl` (legfeljebb ±1 minor verzió eltéréssel a clustertől)
- `curl`, `git`, `cmp` (diffutils)

Telepítési útmutató: [docs/01-kornyezet.md](docs/01-kornyezet.md)

Nincs szükség változófájlra vagy titkos adatra. Minden konfiguráció a `deployment/` mappában van.

## Indítás

A repó gyökeréből:

```bash
kind create cluster --config deployment/kind-config.yaml
```

```bash
kubectl apply -k deployment/
```

```bash
kubectl -n mst rollout status deploy/podinfo --timeout=180s
```

## Elérés és ellenőrzés

Külön terminálban (csak a 127.0.0.1 címre köt):

```bash
kubectl -n mst port-forward svc/podinfo 9898:9898
```

```bash
curl -sS http://127.0.0.1:9898/readyz
```

```bash
curl -sS http://127.0.0.1:9898/version
```

Rekord írása és visszaolvasása:

```bash
curl -sS --data-binary @testdata/record.txt http://127.0.0.1:9898/store
```

```bash
curl -sS http://127.0.0.1:9898/store/<HASH> | cmp - testdata/record.txt && echo MATCH
```

## Ismételt alkalmazás és a container újra-létrehozása adatvesztés nélkül

- A `kubectl apply -k deployment/` bármikor újrafuttatható. Változatlan fájlok esetén minden erőforrás `unchanged`.
- A Pod újra-létrehozása: `kubectl -n mst delete pod -l app.kubernetes.io/name=podinfo`. A Deployment új Podot indít, és az ugyanazt a `podinfo-data` PVC-t csatolja.

## Verziófrissítés és verzióválasztás

Az alkalmazás verzióját **egyetlen sor** határozza meg: `deployment/deployment.yaml`, `image: stefanprodan/podinfo:<TAG>`.

1. Írd át a taget (`6.14.1` → `6.17.0`).
2. Futtasd: `kubectl diff -k deployment/`. Csak a Deployment image-e változhat.
3. Futtasd: `kubectl apply -k deployment/ && kubectl -n mst rollout status deploy/podinfo`.

Új telepítéshez a verziót a git history választja ki (`git checkout podinfo-6.14.1` vagy `podinfo-6.17.0`).
**Már frissített adatokat tartalmazó PVC-vel régebbi verziót nem indítunk.** A régi verzió csak friss, üres tárolóval telepíthető.

## Takarítás (csak a beadás és értékelés után!)

> ⚠️ A `kubectl delete -k deployment/` a PVC-t és vele az adatokat is törli. A tesztek alatt tilos.

Csak az alkalmazás eltávolítása, a tároló megtartásával:

```bash
kubectl -n mst delete deploy/podinfo svc/podinfo
```

A teljes környezet törlése (cluster, PV, minden adat):

```bash
kind delete cluster --name mst
```
