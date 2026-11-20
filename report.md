# Műszaki beszámoló – Podinfo életciklusa Kubernetesen

> **Kitöltési útmutató (beadás előtt töröld ezt a blokkot):** minden `TODO` helyére a saját bizonyítékaidból vett, ténylegesen megfigyelt értéket írd. Ahol a `<…>` jelölés áll, oda a konkrét értéket másold az `evidence/` fájlokból. Tömör legyen: 2–4 oldal elég, a logokra hivatkozz.

## 1. Cél és választott feladatváltozat

- **Hallgatói azonosító:** CFXLIQ
- **Feladatváltozat:** Track A – Podinfo (`stefanprodan/podinfo:6.14.1` → `6.17.0`)
- **Elsődleges telepítési technológia:** Kubernetes, helyi `kind` clusteren, sima YAML manifestekkel és Kustomize-zal (`kubectl apply -k`). Helmet nem használtam. <!-- TODO: 1-2 mondat: miért ezt választottad -->
- **Elvégzett ellenőrzések:** T01–T06 (alapfeladat). T07–T10: NOT ATTEMPTED. <!-- TODO: frissítsd, ha a haladó részt is megcsinálod -->

## 2. Futtatási környezet

Forrás: `evidence/ENV-host.txt`, `evidence/ENV-tools.txt`, `evidence/C1-cluster-info.txt`

| Elem | Érték |
|---|---|
| Hardver | Dell Latitude Pro 16, <!-- TODO: CPU magok, RAM --> |
| Operációs rendszer | <!-- TODO: pl. Ubuntu 24.04.x LTS, kernel … --> |
| Docker Engine | <!-- TODO --> |
| kind | <!-- TODO --> |
| kubectl (kliens) | <!-- TODO --> |
| Kubernetes (szerver / node image) | <!-- TODO --> |
| StorageClass | `standard` (default), provisioner `rancher.io/local-path`, `WaitForFirstConsumer`, reclaim policy <!-- TODO: Delete → Retain, ha átállítottad --> |

## 3. Architektúra

```
 Linux host
 ┌──────────────────────────────────────────────────────────────────────┐
 │  curl ──► 127.0.0.1:9898 ── kubectl port-forward ──┐                   │
 │                                                    │ (API szerveren át) │
 │  Docker: container "mst-control-plane" (kind node) ▼                   │
 │  ┌──────────────── namespace: mst ──────────────────────────────────┐ │
 │  │ Service podinfo  ClusterIP <TODO-IP>:9898 ──► Pod podinfo-…      │ │
 │  │   DNS: podinfo.mst.svc.cluster.local         ├ init: busybox     │ │
 │  │                                              │  chown 100:101    │ │
 │  │                                              └ podinfo :9898     │ │
 │  │                                                 (UID 100/GID 101)│ │
 │  │                                                 /data            │ │
 │  │ PVC podinfo-data (1Gi, RWO) ──► PV <TODO> (local-path, node FS)  │ │
 │  └──────────────────────────────────────────────────────────────────┘ │
 └──────────────────────────────────────────────────────────────────────┘
```

**Erőforrások** (`deployment/`):

| Erőforrás | Név | Lényeges beállítás |
|---|---|---|
| Namespace | `mst` | elkülönítés |
| PersistentVolumeClaim | `podinfo-data` | 1Gi, ReadWriteOnce, default StorageClass |
| Deployment | `podinfo` | 1 replica, `strategy: Recreate`, init container a jogosultsághoz, `--data-path=/data`, nem root (100:101) |
| Service | `podinfo` | ClusterIP, 9898/TCP → container `http` port |

**Címek és portok** (forrás: `evidence/C2-*.txt`):

| Port | Hol figyel | Ki éri el | Indoklás |
|---|---|---|---|
| 9898/TCP | Pod IP <!-- TODO --> | csak a clusteren belül, a Service-en át | ClusterIP, nincs NodePort / LoadBalancer |
| 9898/TCP | host 127.0.0.1 (port-forward) | csak a helyi gép | ideiglenes, kézzel indított alagút |
| 6443/TCP → <!-- TODO: host port --> | host 127.0.0.1 | csak a helyi kubectl | a kind API szerverének alapbeállítása |

<!-- TODO: 3-4 mondat a hálózatról: miért nem publikáltunk portot 0.0.0.0-ra, hogyan működik a Service-név alapú címzés (CoreDNS), mit bizonyít a C2-incluster-client.txt -->

**Jogosultságok:** <!-- TODO: röviden: miért kell az init container, miért nem fsGroup (hostPath alapú local-path), és miért nem fut rootként az alkalmazás -->

## 4. Telepítés

| Lépés | Parancs | Elvárt állapot | Tényleges állapot | Bizonyíték |
|---|---|---|---|---|
| Cluster | `kind create cluster --config deployment/kind-config.yaml` | 1 node Ready | <!-- TODO --> | `C1-cluster-create.txt`, `C1-cluster-info.txt` |
| Előnézet | `kubectl kustomize deployment/` | 4 erőforrás, image 6.14.1 | <!-- TODO --> | `C1-kustomize-render.txt` |
| Alkalmazás | `kubectl apply -k deployment/` | created ×4 | <!-- TODO --> | `C1-apply-1.txt` |
| Rollout | `kubectl -n mst rollout status deploy/podinfo` | successfully rolled out | <!-- TODO --> | `C1-rollout.txt` |
| Állapot | `kubectl -n mst get all,pvc` | PVC Bound, Pod 1/1 Running | <!-- TODO --> | `C1-state.txt` |
| Ismételt apply | `kubectl apply -k deployment/` + `kubectl diff` | unchanged ×4, üres diff | <!-- TODO --> | `C1-apply-2-idempotent.txt` |

Releváns logrészlet (`C1-init-log.txt`, `C1-app-log.txt`):
```
TODO: 2-3 sor
```

## 5. Adatmegőrzés (T03, T04)

- **Tesztrekord:** `testdata/record.txt`, <!-- TODO: N --> bájt, 2 sor
  ```
  MST-ID=CFXLIQ
  MST-NOTE=Track A podinfo persistence test record, line 2
  ```
- **SHA-256:** `<TODO>` · **SHA-1:** `<TODO>`
- **`POST /store` válasza:** `<TODO: HTTP státusz és {"hash":"…"}>`. A hash megegyezik a fájl SHA-1 értékével, vagyis tartalomcímzés történik. <!-- TODO: igaz-e -->
- **Tároló:** PVC `podinfo-data`, UID `<TODO>`, PV `<TODO>`, útvonal a node-on `<TODO>` (`T03-storage-identity.txt`, `T03-node-path.txt`)
- **Visszaolvasás:** `cmp` egyezés (`T03-store-get.txt`)

**Pod-csere:**

| | Pod név | Pod UID | Pod IP | Image | PVC UID |
|---|---|---|---|---|---|
| Előtte (`T04-before.txt`) | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | 6.14.1 | <!-- TODO --> |
| Utána (`T04-after.txt`) | <!-- TODO --> | <!-- TODO --> | <!-- TODO --> | 6.14.1 | <!-- TODO: ugyanaz --> |

Csere módja: `kubectl -n mst delete pod -l app.kubernetes.io/name=podinfo`. A ReplicaSet controller új Podot hozott létre, ugyanazzal a PVC-vel. Visszaolvasás: `T04-store-get.txt`, `cmp` → MATCH. <!-- TODO: ellenőrizd -->

## 6. Verziófrissítés (T05, T06)

| | Előtte (`T05-before-*.txt`) | Utána (`T05-after-*.txt`) |
|---|---|---|
| `/version` | <!-- TODO --> | <!-- TODO --> |
| Deployment image | `stefanprodan/podinfo:6.14.1` | `stefanprodan/podinfo:6.17.0` |
| Futó imageID (digest) | <!-- TODO --> | <!-- TODO --> |
| Pod UID | <!-- TODO --> | <!-- TODO --> |
| PVC UID | <!-- TODO --> | <!-- TODO: ugyanaz --> |

- **Konfigurációmódosítás:** egyetlen sor a `deployment/deployment.yaml`-ban (`T05-config-diff.txt`, git commit `<TODO: hash>`)
- **Előnézet:** a `kubectl diff -k` csak a Deployment image-ét mutatta, a PVC-t nem (`T05-kubectl-diff.txt`)
- **Frissítés:** `kubectl apply -k deployment/` és `rollout status` (`T05-apply.txt`). Recreate stratégia, az új ReplicaSet <!-- TODO: név -->.
- **Az eredeti rekord:** `T06-store-get.txt`, `cmp` → MATCH. Nem hoztam létre újra.
- **Verzióválasztás új telepítéshez:** git tagek (`podinfo-6.14.1`, `podinfo-6.17.0`). Frissített adatú PVC-vel régebbi verziót nem indítunk; régi verzió csak friss tárolóval telepíthető.

## 7. Haladó műveletek

Not attempted. <!-- TODO: frissítsd, ha megcsinálod -->

## 8. Ellenőrzési táblázat

| ID | Parancs (röviden) | Elvárt eredmény | Tényleges eredmény | Állapot | Bizonyíték |
|---|---|---|---|---|---|
| T01 | `curl /readyz` port-forwardon át | HTTP 200, `{"status":"OK"}` | <!-- TODO --> | <!-- PASS/FAIL --> | `evidence/T01-T02-readyz.txt` |
| T02 | `curl` a hostról (127.0.0.1 port-forward), plusz kliens Pod a Service nevén | 200 mindkét úton | <!-- TODO --> | <!-- --> | `evidence/T01-T02-*.txt`, `evidence/C2-incluster-client.txt` |
| T03 | `POST /store`, `GET /store/{hash}`, `cmp` | azonos bájtok | <!-- TODO --> | <!-- --> | `evidence/T03-*.txt` |
| T04 | `kubectl delete pod`, `GET /store/{hash}`, `cmp` | új Pod UID, azonos PVC UID, azonos bájtok | <!-- TODO --> | <!-- --> | `evidence/T04-*.txt` |
| T05 | image tag módosítás, `apply -k`, `/version`, imageID | 6.17.0 fut, új digest | <!-- TODO --> | <!-- --> | `evidence/T05-*.txt` |
| T06 | `GET /store/{hash}`, `cmp` a T03 bájtjaival | azonos bájtok | <!-- TODO --> | <!-- --> | `evidence/T06-store-get.txt` |
| T07 | – | – | – | NOT ATTEMPTED | – |
| T08 | – | – | – | NOT ATTEMPTED | – |
| T09 | – | – | – | NOT ATTEMPTED | – |
| T10 | – | – | – | NOT ATTEMPTED | – |

## 9. Következtetések

**Ami működött:** <!-- TODO -->

**Felmerült problémák és megoldásuk:** <!-- TODO: őszintén; ha nem volt, írd le -->

**Korlátok:**
- Egyetlen node és egyetlen podinfo példány: a Pod cseréje és a frissítés alatt rövid leállás van, és nincs magas rendelkezésre állás.
- A local-path tároló a node (és így a laptop) lemezén van: a node vagy a lemez elvesztése adatvesztéssel jár, és nincs mentés (ez az A3 feladata lenne).
- Nincs TLS, hitelesítés, monitorozás vagy riasztás. Ezek a feladat hatókörén kívül esnek.
- <!-- TODO: saját megfigyelés -->

**Javaslatok éles használatra:** <!-- TODO: pl. replikált vagy hálózati tároló (CSI), rendszeres mentés (pl. Velero), image digest szerinti rögzítés, Ingress TLS-sel, NetworkPolicy, GitOps (Argo CD / Flux), monitorozás (Prometheus – a podinfo exportál metrikákat) -->
