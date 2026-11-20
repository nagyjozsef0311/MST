# Műszaki beszámoló – Podinfo életciklusa Kubernetes környezetben

**Hallgatói azonosító:** CFXLIQ · **Feladatváltozat:** Track A (Podinfo) · **Dátum:** 2026. november 20.

## 1. Cél és választott megoldás

A feladatban egyetlen Podinfo példányt telepítettem tartós tárolóval. Írtam bele egy saját tesztrekordot, lecseréltem az alkalmazás Podját, majd frissítettem az alkalmazást `stefanprodan/podinfo:6.14.1`-ről `6.17.0`-ra. Mindkét lépés után ellenőriztem, hogy az eredeti rekord bájtra pontosan megmaradt.

- **Feladatváltozat:** Track A – Podinfo.
- **Telepítési technológia:** Kubernetes, egy helyi `kind` clusteren (a kind a Kubernetes node-ot egy Docker containerben futtatja). Az erőforrásokat YAML manifestek írják le, és a `kubectl apply -k` (Kustomize) alkalmazza őket egy lépésben. Helmet nem használtam.
- **Miért ezt választottam:** korábban nem dolgoztam Kubernetesszel, és ezt szerettem volna megtanulni, mert a munkaerőpiacon ez a legkeresettebb. A kindet azért választottam, mert egy paranccsal létrehozható és eldobható, és nem kell hozzá VM vagy felhő.
- **Elvégzett ellenőrzések:** T01–T06 (alapfeladat). A haladó részt (T07–T10) nem kíséreltem meg.

**Felhasznált segítség:** mivel nem volt Kubernetes-tapasztalatom, a manifestek elkészítéséhez, a lépések sorrendjéhez és a hibakereséshez egy MI-asszisztenst (Claude) használtam. Minden parancsot én futtattam a saját gépemen; az `evidence/` mappában ezek valódi, szerkesztetlen kimenetei vannak, a sikertelen próbálkozásokkal együtt.

## 2. Futtatási környezet

Forrás: `evidence/ENV-host.txt`, `evidence/ENV-tools.txt`, `evidence/C1-cluster-create.txt`, `evidence/C1-cluster-info.txt`.

| Elem | Érték |
|---|---|
| Hardver | Dell Latitude Pro 16 laptop, 14 CPU szál, 30 GiB RAM, 468 GB SSD |
| Operációs rendszer | Ubuntu 26.04.1 LTS, kernel 7.0.0-43-generic, x86_64 |
| Docker Engine | 29.10.0 (containerd v2.4.2, runc 1.5.3) |
| kind | v0.33.0 |
| kubectl | v1.37.2 (beépített Kustomize v5.8.1) |
| Kubernetes | v1.37.0 (node image `kindest/node:v1.37.0`, a node-on belül Debian 13, containerd 2.3.4) |
| Egyéb | curl 8.18.0, git 2.53.0 |
| StorageClass | `standard` (alapértelmezett), provisioner `rancher.io/local-path`, `WaitForFirstConsumer`, reclaim policy `Delete` |

A kubectl és a szerver verziója között csak patch-eltérés van (1.37.2 és 1.37.0), ez a támogatott tartományon belül van.

## 3. Architektúra

```
 Linux host (Ubuntu 26.04)
 ┌─────────────────────────────────────────────────────────────────────────┐
 │  curl ──► 127.0.0.1:9898 ── kubectl port-forward ──┐                      │
 │  kubectl ─► 127.0.0.1:37085 (API szerver) ─────────┤                      │
 │                                                    ▼                      │
 │  Docker "kind" hálózat: container mst-control-plane (172.18.0.2)          │
 │  ┌──────────────────────── Kubernetes, namespace "mst" ────────────────┐ │
 │  │                                                                     │ │
 │  │  Service "podinfo" (ClusterIP 10.96.225.68:9898)                    │ │
 │  │    DNS: podinfo.mst.svc.cluster.local                               │ │
 │  │        │                                                            │ │
 │  │        ▼                                                            │ │
 │  │  Deployment "podinfo" (1 replica, Recreate) → ReplicaSet → Pod      │ │
 │  │    ├─ init container: busybox:1.37.0  (chown 100:101 /data)         │ │
 │  │    └─ podinfo :9898  (UID 100 / GID 101, --data-path=/data)         │ │
 │  │                         │ /data                                     │ │
 │  │  PVC "podinfo-data" (1Gi, RWO) ──► PV pvc-344730ef-… (local-path)   │ │
 │  │    a node-on: /var/local-path-provisioner/pvc-344730ef-…_mst_podinfo-data │
 │  └─────────────────────────────────────────────────────────────────────┘ │
 └─────────────────────────────────────────────────────────────────────────┘
```

**Erőforrások** (`deployment/` mappa):

| Fájl | Erőforrás | Miért kell |
|---|---|---|
| `kind-config.yaml` | kind cluster `mst` | egy node-os helyi Kubernetes |
| `namespace.yaml` | Namespace `mst` | a feladat erőforrásai külön névtérben vannak |
| `pvc.yaml` | PersistentVolumeClaim `podinfo-data` | 1 GiB tartós tároló; független a Pod élettartamától |
| `deployment.yaml` | Deployment `podinfo` | 1 példány; `strategy: Recreate`, hogy a régi és az új Pod ne használja egyszerre a tárolót; init container a jogosultsághoz; nem root felhasználó |
| `service.yaml` | Service `podinfo` (ClusterIP) | állandó név és cím a Pod előtt (a Pod IP-je minden cserénél változik) |
| `kustomization.yaml` | – | összefogja a fenti fájlokat, és az `mst` névtérbe teszi őket |

**Hálózat és portok** (forrás: `evidence/C2-*.txt`, `evidence/C1-cluster-info.txt`):

| Port | Hol figyel | Ki éri el | Miért |
|---|---|---|---|
| 9898/TCP (container) | a Pod IP-jén (pl. 10.244.0.6) | csak a clusteren belüli Podok, a `podinfo` Service-en (10.96.225.68:9898) keresztül | a Service típusa ClusterIP; nincs NodePort vagy LoadBalancer |
| 9898/TCP (host) | `127.0.0.1:9898` és `[::1]:9898`, a `kubectl port-forward` nyitja | csak a saját gépem | kézzel indított, ideiglenes alagút a teszteléshez |
| 6443/TCP → host 37085 | `127.0.0.1:37085` | csak a saját gépem (kubectl) | a kind így publikálja az API szervert |

Szándékosan semmit nem publikáltam a `0.0.0.0` címre, így a podinfo a helyi hálózat többi gépéről nem érhető el. A `C2-host-listening-ports.txt` szerint a gépen a `127.0.0.1:631` porton is figyel valami: ez a CUPS nyomtatási szolgáltatás, nem a feladat része.

A Podok a Service **nevén** érik el egymást. A `C2-incluster-client.txt` szerint egy eldobható kliens Pod (`curlimages/curl:8.17.0`) a `podinfo.mst.svc.cluster.local` nevet a cluster DNS-szerverén (CoreDNS, 10.96.0.10) a 10.96.225.68 címre oldotta fel, és a `http://podinfo:9898/readyz` kérésre `200 OK` választ kapott. A Service mögött lévő tényleges Pod címét az EndpointSlice mutatja (`C2-service-endpoints.txt`: 10.244.0.6:9898).

**Jogosultságok:** a podinfo image `app` felhasználóval fut (UID 100, GID 101), és nem rootként indítom. Az alkalmazás konténere minden Linux képességet eldob (`drop: ALL`), és nem kaphat magasabb jogot (`allowPrivilegeEscalation: false`). Hogy a `/data` könyvtárba írni tudjon, egy rövid init container a podinfo indulása előtt beállítja a könyvtár tulajdonosát (`chown 100:101 /data`, `chmod 0750 /data`). Ez a container rootként fut, de csak a `CHOWN` és a `FOWNER` képességet kapja meg. Kubernetesben az `fsGroup` beállítás szokott erre szolgálni, de a kind `local-path` tárolója hostPath alapú, és ott ez nem állítja át a tulajdonost.

## 4. Telepítés

| Lépés | Parancs | Elvárt | Tényleges | Bizonyíték |
|---|---|---|---|---|
| Cluster | `kind create cluster --config deployment/kind-config.yaml` | a cluster elindul | 1. próba: `exit 127` (hibás kind bináris, lásd 9.2); 2. próba: sikeres, a node `Ready` | `C1-cluster-create.txt`, `C1-cluster-info.txt` |
| Előnézet | `kubectl kustomize deployment/` | 4 erőforrás, 1 replica, image 6.14.1, `/data` csatolás | ugyanez | `C1-kustomize-render.txt` |
| Telepítés | `kubectl apply -k deployment/` | 4× `created` | 4× `created` | `C1-apply-1.txt` |
| Várakozás | `kubectl -n mst rollout status deploy/podinfo` | `successfully rolled out` | ugyanez | `C1-rollout.txt` |
| Állapot | `kubectl -n mst get all,pvc -o wide; kubectl get pv` | PVC `Bound`, Pod `1/1 Running` | PVC `Bound` (`pvc-344730ef-…`), Pod `podinfo-59f7587cbd-t9sb4` `1/1 Running` | `C1-state.txt` |
| Ismételt alkalmazás | `kubectl apply -k deployment/` + `kubectl diff -k deployment/` | 4× `unchanged`, üres diff | 4× `unchanged`, `NINCS ELTERES` | `C1-apply-2-idempotent.txt` |

Az init container és a podinfo logja (`C1-init-log.txt`, `C1-app-log.txt`):

```
drwxr-x---    2 100      101           4096 Nov 20 10:18 /data
{"level":"info",...,"msg":"Starting podinfo","version":"6.14.1",...,"port":"9898"}
```

**Hogyan alkalmazható újra a konfiguráció, és hogyan hozható újra létre a container adatvesztés nélkül?** A `kubectl apply -k deployment/` bármikor újrafuttatható: mindig a fájlokban leírt állapotra hozza a clustert, és ha nincs eltérés, nem változtat semmit (`C1-apply-2-idempotent.txt`, `T06-apply-again-idempotent.txt`). Az alkalmazás Podját a `kubectl -n mst delete pod -l app.kubernetes.io/name=podinfo` paranccsal lehet újra létrehozni. A Deployment (pontosabban a ReplicaSet) ilyenkor magától új Podot indít, amely ugyanazt a `podinfo-data` PVC-t csatolja. A PVC egy külön Kubernetes objektum, a Pod törlése nem érinti.

**A beadás előtti ellenőrzés: a README reprodukálhatósága.** Miután a YAML fájlokból kivettem a kommenteket, a futó clusteren a `kubectl diff -k deployment/` üres maradt (`C1-comment-cleanup.txt`), vagyis a kommentek törlése a konfigurációt nem változtatta meg. Ezután a README lépéseit szó szerint követve egy második, eldobható clusteren (`mst2`) a teljes életciklust megismételtem (`C1-readme-repro.txt`):

- telepítés 6.14.1-gyel, a PVC `Bound` lett;
- `/readyz` 200, a kliens Pod elérte a Service-t;
- rekordírás: ugyanaz a hash (`b8e715ae…`), visszaolvasás `MATCH`;
- Pod-csere (UID `dd56d416…` → `42ccf9b1…`), `MATCH`;
- frissítés 6.17.0-ra, ugyanazzal a digesttel (`fa2f27c1…`), `MATCH`;
- ismételt apply: `unchanged`, üres diff, és a `deployment.yaml` a végén ugyanaz volt, mint a kiinduló állapotban (üres `git diff`).

Ezután a `mst2` clustert töröltem. Az eredeti `mst` clusterben a Pod (`podinfo-6c784dc597-74dvc`) és a PVC (`344730ef-…`, `Bound`) változatlanul megmaradt. Megfigyeltem, hogy közvetlenül a cluster létrehozása után a node néhány másodpercig `NotReady` állapotú volt; ez a telepítést nem zavarta, és a README-be is beírtam.

**Hogyan választható ki a verzió új telepítéshez?** A verziót kizárólag a `deployment/deployment.yaml` `image:` sora határozza meg; a beadott állapotban ez `6.17.0`. Új telepítés ezzel a verzióval a README 1–3. lépésével történik. Ha valaki az eredeti `6.14.1`-gyel akar kezdeni, az első telepítés előtt visszaírja a taget (README 2. lépés). Ezt **csak új clusterben, üres PVC-vel** szabad megtenni. Olyan tárolóra, amelyet a 6.17.0 már használt, nem indítok régebbi verziót, mert a régebbi alkalmazás nem feltétlenül kezeli helyesen az újabb által írt adatot. A git historyban mindkét állapot megvan: `dc7a03e` (6.14.1) és `7d4602a` (6.17.0).

## 5. Adatmegőrzés (T03, T04)

### Tesztrekord (T03)

A `testdata/record.txt` két ASCII sort tartalmaz, összesen 71 bájtot. Az elvárt tartalmat és az ellenőrző összegeit az első írás **előtt** elmentettem (`T03-expected.txt`, `T03-expected-record.txt`):

```
MST-ID=CFXLIQ$
MST-NOTE=Track A podinfo persistence test record, line 2$
71 testdata/record.txt
SHA-256: 2df87d1b5cb3829ca3e40ca3f1fae0508df1ac124ec5ea9c8a4ead866f940ad5
SHA-1:   b8e715ae1a133891a61753cfa81fb2d5b6def9b1
```

Az írás (`curl --data-binary @testdata/record.txt …/store`) válasza `HTTP/1.1 202 Accepted` és `{"hash": "b8e715ae1a133891a61753cfa81fb2d5b6def9b1"}` lett (`T03-store-post.txt`). A hash megegyezik a fájl SHA-1 összegével, vagyis a podinfo a tartalom alapján nevezi el a fájlt. Ez a név csak cím; az egyezést ettől függetlenül `cmp`-vel és SHA-256-tal ellenőriztem.

A visszaolvasás (`GET /store/b8e715ae…`) után a `cmp` nem talált eltérést, és a két SHA-256 azonos (`T03-store-get.txt`: `MATCH`, `exit code: 0`). Megfigyeltem, hogy a podinfo olvasáskor is `202`-es státuszt ad, nem `200`-at. Ezért az ellenőrzésben nem a státuszkódra, hanem a bájtszintű összehasonlításra támaszkodtam.

### A tároló azonosítása

| | Érték | Bizonyíték |
|---|---|---|
| PVC | `podinfo-data`, UID `344730ef-eaeb-4a80-a163-74d1bd41256e`, `Bound`, StorageClass `standard` | `T03-storage-identity.txt` |
| PV | `pvc-344730ef-eaeb-4a80-a163-74d1bd41256e` | `T03-storage-identity.txt` |
| Fizikai hely (a kind node-on) | `/var/local-path-provisioner/pvc-344730ef-eaeb-4a80-a163-74d1bd41256e_mst_podinfo-data` | `T03-node-path.txt` |
| A fájl | `b8e715ae1a133891a61753cfa81fb2d5b6def9b1`, 71 bájt, tulajdonos 100:101 | `T03-data-dir.txt`, `T03-node-path.txt` |

A PV reclaim policyjét `Delete`-ről `Retain`-re állítottam (`T03-pv-retain.txt`). Így ha a PVC véletlenül törlődne, a PV és az adat akkor is megmaradna.

### Az alkalmazás Podjának lecserélése (T04)

**1. kísérlet – FAIL.** Töröltem a `podinfo-59f7587cbd-t9sb4` Podot (UID `aa4909c1-ff45-41e2-9b52-aaa73f634a0a`). A ReplicaSet azonnal létrehozta az új `podinfo-59f7587cbd-9pv7s` Podot, de az 180 másodperc alatt sem lett `Ready` (`T04-replace.txt`, `exit code: 1`). A hibakeresés (`T04-debug.txt`) szerint a Pod `Init:Error` és `CrashLoopBackOff` állapotban volt, az init container logjában pedig ez állt: `chown: /data: Permission denied`. Az okot és a javítást a 9.2. pont írja le. Az adat ez idő alatt sértetlen maradt: a node-on ellenőriztem, hogy a 71 bájtos fájl a helyén van (`T04-debug.txt`, utolsó bejegyzés). A rekordot nem írtam újra.

**Javítás.** Az init container parancsából kivettem a `-R` kapcsolót (`T04-fix.txt`: `git diff`, `kubectl diff`, `kubectl apply`; git commit `99e12b2`). A `kubectl diff` szerint csak a Deployment init container parancsa változott. Az alkalmazás után létrejött egy új ReplicaSet (`podinfo-7486c4bcb7`), a régi 0-ra skálázódott, az új Pod (`podinfo-7486c4bcb7-k62nx`) pedig elindult.

**2. kísérlet – PASS.** Megismételtem a teljes T04 ellenőrzést, vagyis pontosan azt a helyzetet, ami először elbukott:

| | Pod | Pod UID | Pod IP | Image | PVC UID |
|---|---|---|---|---|---|
| Előtte (`T04-before.txt`) | `podinfo-7486c4bcb7-k62nx` | `eb604e01-7e84-4235-b476-904883d6760a` | 10.244.0.9 | `stefanprodan/podinfo:6.14.1` | `344730ef-…` |
| Utána (`T04-after.txt`) | `podinfo-7486c4bcb7-p8xnk` | `4fe4a2e9-f0a7-458d-b815-cb800c214506` | 10.244.0.10 | `stefanprodan/podinfo:6.14.1` | `344730ef-…` |

A Pod új nevet, UID-t és IP-t kapott; az image és a PVC ugyanaz maradt. A törlés és az új Pod elkészülése sikeres volt (`T04-replace.txt`, második bejegyzés: `condition met`, `exit code: 0`). A visszaolvasott 71 bájt `cmp` szerint azonos az eredetivel, a SHA-256 is egyezik (`T04-store-get.txt`: `MATCH`).

## 6. Verziófrissítés (T05, T06)

| | Előtte (`T05-before-*.txt`) | Utána (`T05-after-*.txt`) |
|---|---|---|
| `GET /version` | `"version": "6.14.1"`, commit `eec06d1…` | `"version": "6.17.0"`, commit `fd3a834…` |
| A Deployment image-e | `stefanprodan/podinfo:6.14.1` | `stefanprodan/podinfo:6.17.0` |
| A futó image digestje | `sha256:f9537f729129d339aaef049b76ab2cd4ff06a424f99e5f6a5923c10621018fb1` | `sha256:fa2f27c1a8561097e5144bfc0853eba6054d743b68b03de4cad4675616ddefb0` |
| Pod | `podinfo-7486c4bcb7-p8xnk` | `podinfo-6c784dc597-74dvc` (UID `03caf854-ae17-4f65-bfef-0020427dd496`) |
| ReplicaSet | `podinfo-7486c4bcb7` (1 Pod) | `podinfo-6c784dc597` (1 Pod); a régiek 0 Poddal megmaradtak |
| PVC UID | `344730ef-eaeb-4a80-a163-74d1bd41256e` | `344730ef-eaeb-4a80-a163-74d1bd41256e` (változatlan) |

**A módosítás:** a `deployment/deployment.yaml` egyetlen sora, `image: stefanprodan/podinfo:6.14.1` → `6.17.0` (`T05-config-diff.txt`, git commit `7d4602a`). Mást nem változtattam.

**Ellenőrzés alkalmazás előtt:** a `kubectl diff -k deployment/` csak a Deployment `image` sorát (és a `generation` számlálót) mutatta; a PVC, a Service és a Namespace nem szerepelt benne (`T05-kubectl-diff.txt`). Ebből előre látszott, hogy a frissítés a tárolóhoz nem nyúl.

**Frissítés:** `kubectl apply -k deployment/` és `kubectl -n mst rollout status deploy/podinfo`. Eredmény: `deployment.apps/podinfo configured`, a többi erőforrás `unchanged`, majd `successfully rolled out` (`T05-apply.txt`). A `Recreate` stratégia miatt a régi Pod előbb leállt, és csak utána indult el az új. A `rollout history` három revíziót mutat: az eredeti telepítést, az init container javítását és a verziófrissítést.

**Az eredeti rekord a frissítés után (T06):** ugyanazzal a hash-sel visszaolvasva a tartalom `cmp` szerint azonos a T03-ban elmentett bájtokkal, és a SHA-256 is egyezik (`T06-store-get.txt`: `MATCH`, `exit code: 0`). A rekordot nem hoztam létre újra. A frissítés utáni ismételt `apply` is 4× `unchanged` és üres diff lett (`T06-apply-again-idempotent.txt`).

## 7. Haladó műveletek

Not attempted. A T07–T10 ellenőrzéseket (Valkey cache, hiba és helyreállás, mentés és visszaállítás, automatizált tesztek) nem végeztem el.

## 8. Ellenőrzési táblázat

| ID | Parancs (röviden) | Elvárt eredmény | Tényleges eredmény | Állapot | Bizonyíték |
|---|---|---|---|---|---|
| T01 | `curl -i http://127.0.0.1:9898/readyz` (port-forwardon át) | HTTP 200, `{"status":"OK"}` | HTTP 200, `{"status": "OK"}`; `/version` → 6.14.1 | PASS | `evidence/T01-T02-readyz.txt`, `evidence/T01-T02-version.txt` |
| T02 | ugyanez a host shelljéből (független kliens), plusz egy kliens Pod a Service nevén | mindkét úton HTTP 200 | host: 200; kliens Pod: DNS → 10.96.225.68, 200 | PASS | `evidence/T01-T02-*.txt`, `evidence/C2-incluster-client.txt` |
| T03 | `POST /store` (`--data-binary`), `GET /store/{hash}`, `cmp`, `sha256sum` | bájtra azonos tartalom | hash = SHA-1; `cmp` egyezés, SHA-256 `2df87d1b…` | PASS | `evidence/T03-*.txt` |
| T04 | `kubectl delete pod …`, `GET /store/{hash}`, `cmp` | új Pod UID, azonos PVC, azonos bájtok | 1. kísérlet: az új Pod nem indult el (init hiba), az adat megmaradt. Javítás után: új UID, azonos PVC UID, `cmp` egyezés | PASS (az 1. kísérlet FAIL volt, lásd 5. és 9.2.) | `evidence/T04-*.txt` |
| T05 | image tag 6.14.1 → 6.17.0 a `deployment.yaml`-ban, `kubectl apply -k`, `/version`, imageID | 6.17.0 fut, új image | `/version` 6.17.0, új digest `fa2f27c1…`, új ReplicaSet | PASS | `evidence/T05-*.txt` |
| T06 | `GET /store/{hash}`, `cmp` a T03 bájtjaival | bájtra azonos tartalom | `cmp` egyezés, SHA-256 azonos, PVC UID változatlan | PASS | `evidence/T06-*.txt` |
| T07 | – | – | – | NOT ATTEMPTED | – |
| T08 | – | – | – | NOT ATTEMPTED | – |
| T09 | – | – | – | NOT ATTEMPTED | – |
| T10 | – | – | – | NOT ATTEMPTED | – |

## 9. Következtetések

### 9.1 Mi működött

A Kubernetes a leírt állapotot tartotta fenn. Amikor töröltem a Podot, a controller automatikusan újat indított. A tartós adat a PVC-ben volt, ezért a Pod cseréje és a verziófrissítés nem érintette. Az eredeti 71 bájtos rekord minden lépés után bájtra azonos maradt, és a PVC azonosítója az egész feladat alatt `344730ef-…` volt. A frissítéshez elég volt egyetlen sort átírni a konfigurációban. A README lépései egy második, új clusteren is hiba nélkül végigvitték a teljes folyamatot. A `kubectl diff` alkalmazás előtt megmutatta, mi fog változni, és a konfiguráció ismételt alkalmazása nem okozott változást.

### 9.2 Felmerült problémák és megoldásuk

1. **Hibás kind letöltés** (`ENV-kind-hibas-letoltes.txt`, `ENV-tools.txt` első bejegyzése, `C1-cluster-create.txt` első bejegyzése). A `kind` parancs ezzel állt le: `line 1: Not: command not found`, kilépési kód 127. Kiderült, hogy a letöltött fájl nem program volt, hanem egy „Not Found” szöveg, mert a letöltési címben rossz volt a verziószám, és a `curl` a hibaoldalt csendben elmentette. A kindet ezután a helyes verzióval (v0.33.0), a `curl -f` kapcsolóval (HTTP-hibánál leáll) és az ellenőrző összeg (`sha256sum --check`) vizsgálatával töltöttem le újra. Tanulság: egy parancs sikeres lefutása még nem jelenti, hogy jó eredményt adott; az eredményt ellenőrizni kell.

2. **Nem idempotens init container (T04 első kísérlete).** Az első Pod gond nélkül elindult, de a csere utáni második Pod init containere elbukott: `chown: /data: Permission denied`. Az ok a következő volt:
   - Az első indításkor a `/data` könyvtárat a local-path tároló hozta létre úgy, hogy mindenki olvashatta, ezért a `chown -R` végig tudta járni.
   - Ezután a `chmod 0750` miatt a könyvtár a 100-as felhasználóé lett, másoknak nem maradt rajta joga.
   - Az init container ugyan rootként fut, de csak a `CHOWN` és `FOWNER` képességet kapta meg. Az ezek mellett szükséges `DAC_READ_SEARCH` képesség nélkül a root sem olvashatta a könyvtár tartalmát, így a `-R` (rekurzív) bejárás második alkalommal elakadt.

   Megoldásként a `-R` kapcsolót elhagytam: a könyvtár tulajdonosának átállításához elég a `CHOWN` képesség, a fájlokat pedig a podinfo eleve 100:101 tulajdonnal hozza létre. A `DAC_READ_SEARCH` hozzáadása is működött volna, de az bármely fájl olvasását megengedte volna, ezért a kevesebb jogot adó megoldást választottam. Tanulság: egy előkészítő lépésnek akárhányszor futtatva ugyanazt kell csinálnia. Ez a hiba csak a második futáskor jött elő, és pont ezt fogta meg a Pod-csere ellenőrzése.

3. **Kisebb, saját hibák és megfigyelések:**
   - A `T03-node-path.txt` első bejegyzésében véletlenül benne hagytam egy helyőrzőt (`<UTVONAL>`) a valódi útvonal helyett. Ez szintaxishibát adott; a második bejegyzés a helyes parancs.
   - A `C2-incluster-client.txt`-ben a kimenet kétszer szerepel, és van benne egy `couldn't attach to pod` figyelmeztetés. A kliens Pod hamarabb végzett, mint ahogy a kubectl rácsatlakozott, ezért a kubectl a Pod logjából írta ki újra ugyanazt. Ez nem befolyásolja az eredményt.
   - A port-forward egy konkrét Podhoz kapcsolódik, ezért minden Pod-csere és frissítés után újra kellett indítanom. A reprodukciós teszt végén egyszer el is felejtettem: az eredeti clusterre visszaváltás után a két első visszaolvasási kísérlet `Failed to connect` hibát adott (`C1-readme-repro.txt` vége), mert nem futott port-forward.
   - Az eseménynaplóban (`T04-debug.txt`) az indulás pillanatában látszik egy-egy sikertelen readiness ellenőrzés (`connection refused`), leálláskor pedig egy `503`. Ez normális: az alkalmazás még nem, illetve már nem fogadott kéréseket, és a Kubernetes ilyenkor nem küld forgalmat a Podra.

### 9.3 Korlátok

- **Egy node, egy példány:** a Pod cseréje és a frissítés alatt az alkalmazás rövid ideig nem érhető el (a `Recreate` stratégia ezt tudatosan vállalja). A leállás hosszát nem mértem. Nincs magas rendelkezésre állás.
- **A tároló a laptopon van:** a PV a kind node containerének fájlrendszerén van. Ha a clustert törlöm (`kind delete cluster`), vagy a gép lemeze tönkremegy, az adat elvész; ez ellen a `Retain` beállítás sem véd. Mentést nem készítettem (ez a haladó A3 feladat lenne).
- **A `kubectl delete -k deployment/`** a PVC-t is törölné. A `Retain` miatt a PV megmaradna, de ezt a parancsot a tesztek alatt nem használtam.
- **A tag nem változtathatatlan:** az image-eket verziótaggel rögzítettem (nem `latest`), de egy tag a registryben elvileg átállítható. A digesteket ezért a bizonyítékokban is rögzítettem.
- **Biztonság:** nincs TLS, hitelesítés vagy hálózati szabály (NetworkPolicy). A szolgáltatás csak a saját gépemen, a `127.0.0.1` címen érhető el. Ez megfelel a feladatnak, de élesben nem lenne elég.
- **Az SHA-1 hash csak cím:** az adat épségét SHA-256-tal és `cmp`-vel ellenőriztem.

### 9.4 Javaslatok éles használatra

- Replikált, hálózati tároló (CSI driver) a node lemeze helyett, és rendszeres, távoli mentés (pl. Velero).
- Image megadása digest szerint (`podinfo@sha256:…`), hogy a futó verzió garantáltan ne változhasson.
- Fájl helyett adatbázis vagy objektumtár, hogy az alkalmazás több példányban is futhasson, és a frissítés leállás nélkül (RollingUpdate) történhessen.
- Ingress TLS-sel és hitelesítéssel a port-forward helyett, valamint NetworkPolicy a forgalom korlátozására.
- A változások nyomon követése: `kubernetes.io/change-cause` annotáció (most a `rollout history` CHANGE-CAUSE oszlopa üres), illetve GitOps eszköz (Argo CD vagy Flux), amely a git tárolóból automatikusan alkalmazza a konfigurációt.
- Monitorozás és riasztás (pl. Prometheus; a podinfo maga is ad metrikákat).
