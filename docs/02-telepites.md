# 02 – Telepítés, elérés és hálózat (T01, T02 · C1, C2)

**Cél:** fusson a cluster, benne a podinfo 6.14.1 egy PVC-vel, és egy független kliensből (a hostról) bizonyíthatóan elérhető legyen.

Mindent a repó gyökeréből futtass, betöltött segédfüggvénnyel:

```bash
cd ~/MST && source scripts/ev.sh
```

---

## Elmélet röviden

Olvasd el a `deployment/` mappa fájljait is: a kommentekben minden döntés indoklása megvan.

| Erőforrás | Fájl | Mire való |
|---|---|---|
| **Namespace** | `namespace.yaml` | Logikai elkülönítés. A feladat erőforrásai nem keverednek a rendszerkomponensekkel. |
| **PersistentVolumeClaim** | `pvc.yaml` | *Igénylés*: „kérek 1 GiB írható tárolót”. A **StorageClass** (kindben: `standard` / local-path) szolgálja ki, és létrehoz hozzá egy **PersistentVolume**-ot. A PVC élettartama **független** a Podétól. |
| **Deployment** | `deployment.yaml` | Leírja, milyen Pod fusson és hány példányban. A Deployment egy **ReplicaSet**-et hoz létre, az pedig gondoskodik arról, hogy mindig 1 Pod fusson. |
| **Service** | `service.yaml` | Stabil név és IP a Pod előtt. A Pod IP-je minden cserénél változik, a Service-é nem. A clusteren belüli DNS-nevét a CoreDNS adja: `podinfo.mst.svc.cluster.local`. |
| **Kustomization** | `kustomization.yaml` | Egy csomagba fogja a fenti fájlokat, és beállítja a névteret. |

Pod vs. container: a **Pod** a Kubernetes legkisebb egysége, egy vagy több container közös hálózati névtérrel és közös volume-okkal. Nálunk két container van benne. Az **init container** lefut és kilép, csak utána indul el a podinfo.

**Deklaratív, idempotens alkalmazás:** a `kubectl apply` mindig a fájlban leírt állapotra hozza a clustert. Ha semmi nem változott, a második futtatás eredménye `unchanged`. Ez a C1 „megismételhető telepítés” lényege.

---

## 2.1 A cluster létrehozása

```bash
ev C1-cluster-create.txt 'kind create cluster --config deployment/kind-config.yaml'
```

```bash
ev C1-cluster-info.txt 'kubectl cluster-info; kubectl version; kubectl get nodes -o wide; kubectl get storageclass'
```

**Mire számíts:** egy `mst-control-plane` nevű node `Ready` állapotban, és egy `standard (default)` StorageClass, `rancher.io/local-path` provisionerrel és `WaitForFirstConsumer` binding móddal.

A kind beállította a `kubectl` kontextusát (`kind-mst`). Ellenőrizheted így: `kubectl config current-context`.

## 2.2 Előnézet és telepítés

Mielőtt bármit alkalmazol, nézd meg, mi jönne létre. Ez jó szokás, élesben kötelező.

```bash
ev C1-kustomize-render.txt 'kubectl kustomize deployment/'
```

Nézd át a kimenetet: 1 replica, image `stefanprodan/podinfo:6.14.1`, a PVC a `/data`-ra van csatolva, és mindenhol `namespace: mst` szerepel.

```bash
ev C1-apply-1.txt 'kubectl apply -k deployment/'
```

```bash
ev C1-rollout.txt 'kubectl -n mst rollout status deploy/podinfo --timeout=180s'
```

Ha a rollout elakad, a hibakeresés sorrendje: `kubectl -n mst get pods`, aztán `kubectl -n mst describe pod -l app.kubernetes.io/name=podinfo` (a végén lévő *Events* rész a fontos), végül `kubectl -n mst logs deploy/podinfo -c fix-data-permissions` és `... -c podinfo`.

## 2.3 Az állapot rögzítése

```bash
ev C1-state.txt 'kubectl -n mst get all,pvc -o wide; kubectl get pv'
```

**Mire számíts:** a PVC `Bound` állapotú, a Pod `1/1 Running`, a Service `ClusterIP`.

Az init container logja megmutatja, hogy a jogosultság-beállítás lefutott (`drwxr-x--- ... 100 101 ... /data`):

```bash
ev C1-init-log.txt 'kubectl -n mst logs deploy/podinfo -c fix-data-permissions'
```

A podinfo saját logja (indulási üzenet, verzió):

```bash
ev C1-app-log.txt 'kubectl -n mst logs deploy/podinfo -c podinfo --tail=20'
```

## 2.4 Ismételt alkalmazás

```bash
ev C1-apply-2-idempotent.txt 'kubectl apply -k deployment/; kubectl diff -k deployment/ && echo "NINCS ELTERES"'
```

**Mire számíts:** minden sorban `unchanged`, és üres diff után a `NINCS ELTERES` felirat. Ez bizonyítja, hogy az ismételt alkalmazás biztonságos.

## 2.5 T01 + T02: elérés független kliensből (a hostról)

Nyiss egy **második terminált**, és hagyd ott futni:

```bash
kubectl -n mst port-forward svc/podinfo 9898:9898
```

> **Elmélet:** a `port-forward` egy titkosított alagutat nyit a kubectl-en és az API szerveren át a Podig. Alapból csak a `127.0.0.1` címre köt, így a hálózatod többi gépe nem éri el. Ezt kéri a C2. Ha a 9898 foglalt a hoston, válassz másik helyi portot (pl. `19898:9898`); a container portját ne változtasd meg.

Az első terminálban:

```bash
ev T01-T02-readyz.txt 'curl -sS -i http://127.0.0.1:9898/readyz'
```

```bash
ev T01-T02-version.txt 'curl -sS -i http://127.0.0.1:9898/version'
```

**Mire számíts:** `HTTP/1.1 200 OK` és `{"status":"OK"}`, illetve egy JSON, benne `"version":"6.14.1"`.

Ez a két bizonyíték egyszerre igazolja a T01-et (az alkalmazás kész) és a T02-t (egy független kliens, a host shellje, eléri).

## 2.6 C2: hálózati bizonyítékok

**a) Service, végpontok, DNS.** Egy eldobható kliens Pod a clusteren belül, a Service *nevén* éri el az alkalmazást. Ez a containerek közötti kommunikáció és a névfeloldás bizonyítéka.

```bash
ev C2-service-endpoints.txt 'kubectl -n mst get svc podinfo -o wide; kubectl -n mst get endpointslices -l kubernetes.io/service-name=podinfo -o wide; kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o wide'
```

```bash
ev C2-incluster-client.txt 'kubectl -n mst run netcheck --rm -i --restart=Never --image=curlimages/curl:8.17.0 -- sh -c "nslookup podinfo.mst.svc.cluster.local || true; curl -sS -i http://podinfo:9898/readyz"'
```

Megjegyzés: a `curlimages/curl` image-ben lehet, hogy nincs `nslookup`; ezért van ott a `|| true`. A sikeres `curl http://podinfo:9898` már önmagában bizonyítja a DNS-feloldást.

**b) Mi látszik a hoston kívülről?** Listázd a hoston figyelő TCP portokat:

```bash
ev C2-host-listening-ports.txt 'ss -ltnp | grep -E "9898|127.0.0.1" ; docker ps --format "table {{.Names}}\t{{.Ports}}"'
```

**Mire számíts:** a `kubectl` a `127.0.0.1:9898`-on figyel (a port-forward), a kind node pedig csak az API szerver portját publikálja, szintén a `127.0.0.1`-re (`127.0.0.1:<véletlen port>->6443/tcp`). **Nem** lesz `0.0.0.0` címre kötött alkalmazásport.

Ezt kell majd a beszámolóban leírnod:

| Port | Hol figyel | Ki éri el | Miért |
|---|---|---|---|
| 9898/TCP (container) | Pod IP (cluster belső hálózata) | csak clusteren belüli Podok, a Service-en át | ClusterIP Service, nincs NodePort / LoadBalancer |
| 9898/TCP (host) | 127.0.0.1, a `kubectl port-forward` nyitja | csak a helyi gép | ideiglenes, kézzel indított alagút |
| 6443/TCP → véletlen host port | 127.0.0.1 | csak a helyi gép (kubectl) | a kind alapbeállítása |

## 2.7 Commit

```bash
git add evidence/ && git commit -m "Telepites: podinfo 6.14.1 kind clusteren, T01-T02 bizonyitekok"
```

## Ellenőrzőlista

- [ ] A PVC `Bound`, a Pod `1/1 Running`
- [ ] Megvan a `T01-T02-readyz.txt` és a `T01-T02-version.txt`, mindkettőben `200 OK`
- [ ] Az ismételt apply mindenhol `unchanged`-et ad
- [ ] Megvan a kliens Pod és a porttábla bizonyítéka

## Gyakori hibák

| Tünet | Ok | Megoldás |
|---|---|---|
| A Pod `Init:Error` vagy `Init:CrashLoopBackOff` | az init container nem tudta beállítani a jogosultságot | `kubectl -n mst logs deploy/podinfo -c fix-data-permissions` |
| A Pod `Pending`, és a PVC is `Pending` | a scheduler nem talál helyet, vagy a provisioner hibás | `kubectl -n mst describe pvc podinfo-data` és `kubectl -n local-path-storage logs deploy/local-path-provisioner` |
| `ErrImagePull` | hálózati vagy registry hiba, esetleg elírt tag | `describe pod`, Events rész |
| `curl: (7) Failed to connect` | nem fut a port-forward | indítsd újra a második terminálban |

**Következő:** [03-adatmegorzes.md](03-adatmegorzes.md)
