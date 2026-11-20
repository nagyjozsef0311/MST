# MST féléves feladat – Track A: Podinfo életciklusa Kubernetesen

| | |
|---|---|
| Hallgatói azonosító | `CFXLIQ` |
| Feladatváltozat | **Track A – Podinfo** (`stefanprodan/podinfo:6.14.1` → `6.17.0`) |
| Telepítési technológia | **Kubernetes** helyi `kind` clusteren, YAML manifestek + Kustomize (`kubectl apply -k`) |
| Műszaki beszámoló | [report.md](report.md) |
| Bizonyítékok | [evidence/](evidence/) (tartalomjegyzék: [evidence/README.md](evidence/README.md)) |

## Könyvtárszerkezet

```
mst-project/
├── README.md               telepítési és futtatási útmutató (ez a fájl)
├── report.md               műszaki beszámoló
├── deployment/             a telepítés forrásállományai
│   ├── kind-config.yaml    helyi, egy node-os Kubernetes cluster
│   ├── kustomization.yaml  belépési pont: kubectl apply -k deployment/
│   ├── namespace.yaml      "mst" névtér
│   ├── pvc.yaml            podinfo-data PVC (1Gi, ReadWriteOnce)
│   ├── deployment.yaml     podinfo Deployment (1 példány, Recreate, init container, image tag)
│   └── service.yaml        belső ClusterIP Service, 9898/TCP
├── scripts/ev.sh           segédfüggvény a parancskimenetek rögzítéséhez
├── testdata/record.txt     a tesztrekord (az elvárt bájtok)
└── evidence/               a ténylegesen lefuttatott parancsok kimenetei
```

## 0. Előfeltételek

Linux x86_64 gép, internetkapcsolattal (image letöltéshez). A megoldást ezekkel a verziókkal futtattam (`evidence/ENV-tools.txt`):

| Eszköz | Használt verzió | Telepítés |
|---|---|---|
| Docker Engine | 29.10.0 | https://docs.docker.com/engine/install/ubuntu/ |
| kind | v0.33.0 | lásd lent |
| kubectl | v1.37.2 | lásd lent |
| curl, git, cmp (diffutils), sha256sum | rendszercsomagok | `sudo apt-get install -y curl git diffutils` |

A felhasználó legyen a `docker` csoport tagja (`sudo usermod -aG docker "$USER"`, utána ki- és bejelentkezés), hogy a `docker` és a `kind` sudo nélkül fusson.

**kubectl** (a hivatalos bináris, ellenőrző összeggel):

```bash
cd /tmp && curl -fLO "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && curl -fLO "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**kind** (a használt v0.33.0 verzió, ellenőrző összeggel):

```bash
cd /tmp && curl -fLo kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64 && curl -fLo kind.sha256sum https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-amd64.sha256sum && echo "$(cut -d' ' -f1 kind.sha256sum)  kind" | sha256sum --check && sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
```

Mindkét parancsnak `OK` sort kell kiírnia. Ellenőrzés:

```bash
docker version && kind version && kubectl version --client
```

**Változók, titkos adatok:** nincsenek. Nincs jelszó, token vagy változófájl, minden beállítás a `deployment/` mappában van. A `kubectl` hozzáférési adatai (kubeconfig) a `~/.kube/config` fájlban vannak, a projekten kívül.

**Minden további parancsot a projekt gyökérkönyvtárából futtass** (abból a mappából, amelyben ez a README van).

## 1. A cluster létrehozása

```bash
kind create cluster --config deployment/kind-config.yaml
```

Ez egy `mst` nevű, egy node-os clustert hoz létre (a node egy `mst-control-plane` nevű Docker container), és a `kubectl`-t erre állítja (kontextus: `kind-mst`). Ha már van `mst` nevű cluster, más nevet is adhatsz: `--name mst2`. Ekkor a kontextus `kind-mst2` lesz.

Ellenőrzés (a node `Ready`, és van `standard (default)` StorageClass). Közvetlenül a létrehozás után a node néhány másodpercig `NotReady` lehet; ez normális, a telepítés ettől függetlenül folytatható:

```bash
kubectl get nodes && kubectl get storageclass
```

## 2. Verzió kiválasztása

Az alkalmazás verzióját **egyetlen sor** határozza meg: a `deployment/deployment.yaml` fájlban az `image: stefanprodan/podinfo:<TAG>` sor. A beadott állapotban ez **`6.17.0`** (a frissítés utáni állapot).

- **Új telepítés a frissített verzióval:** nincs teendő, mehet a 3. lépés.
- **A teljes életciklus megismétlése (6.14.1-ről indulva):** az első telepítés előtt állítsd vissza a taget:

  ```bash
  sed -i 's#stefanprodan/podinfo:6.17.0#stefanprodan/podinfo:6.14.1#' deployment/deployment.yaml && grep -n 'podinfo:' deployment/deployment.yaml
  ```

> **Figyelem:** a 6.14.1-et **csak friss clusterbe, üres PVC-vel** szabad telepíteni. Olyan PVC-re, amelyet már a 6.17.0 használt, nem indítunk régebbi verziót (downgrade), mert a régebbi verzió nem feltétlenül kezeli helyesen az újabb által írt adatot.

## 3. Telepítés

Előnézet, ami semmit nem módosít. Itt ellenőrizheted az image-et, a példányszámot (1) és a `/data` csatolást:

```bash
kubectl kustomize deployment/
```

Telepítés, majd várakozás, amíg a Pod elkészül (az első indításnál az image letöltése 1–2 percig is tarthat):

```bash
kubectl apply -k deployment/
```

```bash
kubectl -n mst rollout status deploy/podinfo --timeout=180s
```

Elvárt állapot: a PVC `Bound`, a Pod `1/1 Running`, a Service `ClusterIP`:

```bash
kubectl -n mst get pods,svc,pvc -o wide
```

## 4. Elérés és működés ellenőrzése

A Service csak a clusteren belül érhető el. A hostról **egy második terminálban** nyiss port-forwardot, és hagyd futni. Ez csak a `127.0.0.1` (és `::1`) címre köt:

```bash
kubectl -n mst port-forward svc/podinfo 9898:9898
```

Ha a 9898-as port foglalt a hoston, válassz másikat (pl. `19898:9898`), és a lenti címekben is azt használd.

Az első terminálban (elvárt eredmény: `HTTP/1.1 200 OK`, `{"status": "OK"}`, illetve a futó verzió):

```bash
curl -sS -i http://127.0.0.1:9898/readyz
```

```bash
curl -sS http://127.0.0.1:9898/version
```

Ellenőrzés a clusteren belülről, a Service nevén keresztül (eldobható kliens Pod):

```bash
kubectl -n mst run netcheck --rm -i --restart=Never --image=curlimages/curl:8.17.0 -- curl -sS -i http://podinfo:9898/readyz
```

> **Fontos:** a port-forward egy konkrét Podhoz kapcsolódik. Minden Pod-csere és frissítés után megszakad; ilyenkor a második terminálban indítsd újra ugyanazzal a paranccsal.

## 5. Tesztrekord írása és visszaolvasása

A tesztrekord a `testdata/record.txt` (71 bájt, 2 sor, benne `MST-ID=CFXLIQ`). A `--data-binary` pontosan a fájl bájtjait küldi el. A válaszból a 40 jegyű hash-t eltesszük egy változóba és egy fájlba:

```bash
HASH=$(curl -sS --data-binary @testdata/record.txt http://127.0.0.1:9898/store | grep -o '[0-9a-f]\{40\}') && echo "$HASH" | tee /tmp/podinfo-hash.txt
```

A hash a tartalom SHA-1 összege, ezért meg kell egyeznie ezzel:

```bash
sha1sum testdata/record.txt
```

Visszaolvasás és bájtszintű összehasonlítás (elvárt kimenet: `MATCH`):

```bash
curl -sS http://127.0.0.1:9898/store/$HASH | cmp - testdata/record.txt && echo MATCH
```

Új terminálban a változót előbb töltsd vissza: `HASH=$(cat /tmp/podinfo-hash.txt)`.

## 6. Az alkalmazás Podjának lecserélése adatvesztés nélkül

A Pod törlése után a Deployment automatikusan új Podot hoz létre (új név, új UID), ugyanazzal a `podinfo-data` PVC-vel. A PVC-t nem töröljük.

```bash
kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o custom-columns=POD:.metadata.name,UID:.metadata.uid
```

```bash
kubectl -n mst delete pod -l app.kubernetes.io/name=podinfo --wait=true && kubectl -n mst wait pod -l app.kubernetes.io/name=podinfo --for=condition=Ready --timeout=180s
```

```bash
kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o custom-columns=POD:.metadata.name,UID:.metadata.uid
```

Indítsd újra a port-forwardot, majd olvasd vissza ugyanazt a rekordot. **Ne írd újra!**

```bash
curl -sS http://127.0.0.1:9898/store/$HASH | cmp - testdata/record.txt && echo MATCH
```

## 7. Verziófrissítés (6.14.1 → 6.17.0)

Régi verzió rögzítése:

```bash
curl -sS http://127.0.0.1:9898/version
```

Az image tag módosítása a telepítési fájlban (ez az egyetlen változás):

```bash
sed -i 's#stefanprodan/podinfo:6.14.1#stefanprodan/podinfo:6.17.0#' deployment/deployment.yaml && grep -n 'podinfo:' deployment/deployment.yaml
```

Előnézet: csak a Deployment `image` sora változhat, a PVC nem. A parancs 1-es kilépési kóddal jelzi, hogy eltérést talált:

```bash
kubectl diff -k deployment/
```

Alkalmazás:

```bash
kubectl apply -k deployment/ && kubectl -n mst rollout status deploy/podinfo --timeout=180s
```

Indítsd újra a port-forwardot, majd ellenőrizd az új verziót és az eredeti rekordot:

```bash
curl -sS http://127.0.0.1:9898/version
```

```bash
kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o jsonpath='{.items[0].status.containerStatuses[0].image}{"\n"}{.items[0].status.containerStatuses[0].imageID}{"\n"}'
```

```bash
curl -sS http://127.0.0.1:9898/store/$HASH | cmp - testdata/record.txt && echo MATCH
```

## 8. A konfiguráció ismételt alkalmazása

A `kubectl apply -k deployment/` bármikor újrafuttatható. Ha a fájlok nem változtak, minden erőforrás `unchanged`, és a `kubectl diff` üres:

```bash
kubectl apply -k deployment/ && kubectl diff -k deployment/ && echo "NINCS ELTERES"
```

## 9. Bizonyítékok rögzítése (opcionális)

A `scripts/ev.sh` egy segédfüggvényt ad, amely a parancsot, a teljes kimenetet, az időpontot és a kilépési kódot hozzáfűzi az `evidence/<fájl>` végéhez:

```bash
source scripts/ev.sh
```

```bash
ev T01-T02-readyz.txt 'curl -sS -i http://127.0.0.1:9898/readyz'
```

## 10. Leállítás és takarítás

> **Figyelem:** a `kubectl delete -k deployment/` a PVC-t is törli. A tesztek alatt ne használd.

Csak az alkalmazás leállítása, a tárolt adat megtartásával. Később a 3. lépéssel újraindítható, és ugyanazt a PVC-t kapja vissza:

```bash
kubectl -n mst scale deploy/podinfo --replicas=0
```

A teljes környezet törlése (a cluster, a PVC/PV és **minden tárolt adat**):

```bash
kind delete cluster --name mst
```

## Hibaelhárítás

| Tünet | Teendő |
|---|---|
| A Pod `Pending` / `Init:Error` / `CrashLoopBackOff` | `kubectl -n mst describe pod -l app.kubernetes.io/name=podinfo` (a végén lévő Events rész), illetve `kubectl -n mst logs deploy/podinfo -c fix-data-permissions` és `-c podinfo` |
| `curl: (7) Failed to connect to 127.0.0.1 port 9898` | Nem fut a port-forward, vagy egy Pod-csere miatt megszakadt: indítsd újra |
| `/version` frissítés után is a régi verziót mutatja | Indítsd újra a port-forwardot; nézd meg, mi az elvárt image: `kubectl -n mst get deploy podinfo -o yaml \| grep image:` |
| `kind: ... Not: command not found` | A kind letöltése hibás volt (a „Not Found” oldal mentődött el): töltsd le újra a fenti, `curl -f`-es paranccsal |
