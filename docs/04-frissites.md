# 04 – Verziófrissítés az adatok megőrzésével (T05, T06 · C4)

**Cél:** a `stefanprodan/podinfo:6.14.1` image cseréje `6.17.0`-ra, *kizárólag a telepítési fájl módosításával*. Utána bizonyítod, hogy az új verzió fut, és a T03-ban írt rekord változatlan.

```bash
cd ~/MST && source scripts/ev.sh && export HASH=$(cat evidence/T03-hash.txt)
```

A második terminálban fusson a port-forward.

---

## Elmélet röviden

**Mi a frissítés Kubernetesben?** Átírod a Deployment Pod-sablonjában az image-et, és alkalmazod. A Deployment controller azt látja, hogy a sablon megváltozott (más a *pod-template-hash*), ezért **új ReplicaSet**-et hoz létre az új sablonnal, a régit pedig 0-ra skálázza. A régi ReplicaSet megmarad, erre épül a `kubectl rollout undo`.

**Recreate vs. RollingUpdate.** A RollingUpdate (alapértelmezett) előbb elindítja az újat, és csak utána állítja le a régit: nincs leállás. Csakhogy nálunk egy ReadWriteOnce PVC és egy fájlalapú adattár van, és nem jó, ha két verzió egyszerre írja ugyanazt a könyvtárat. Ezért **Recreate**: előbb leáll a régi, aztán indul az új. Ára néhány másodperc leállás, amit a kiírás kifejezetten megenged.

**Tag és digest.** A `/version` végpont azt mondja meg, mit *gondol magáról* az alkalmazás. A Pod `imageID` mezője viszont a ténylegesen futtatott image **digestje**. Mindkettőt rögzítjük, mert együtt erős bizonyítékot adnak.

**Miért nem szabad visszafelé lépni (C1)?** Ha egy újabb verzió már írt az adatokba, és azok formátuma megváltozott, egy régebbi verzió nem feltétlenül tudja olvasni őket. A szabály: **meglévő PVC-n soha ne indíts régebbi verziót.** A verziót a git history választja ki (lásd 4.6), a régi verzió pedig csak friss, üres tárolóval telepíthető.

---

## 4.1 T05 – a régi, ténylegesen futó verzió rögzítése

```bash
ev T05-before-version.txt 'curl -sS -i http://127.0.0.1:9898/version'
```

```bash
ev T05-before-image.txt 'kubectl -n mst get deploy podinfo -o jsonpath="spec image: {.spec.template.spec.containers[0].image}{\"\\n\"}"; kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o jsonpath="{range .items[*]}pod: {.metadata.name} uid: {.metadata.uid}{\"\\n\"}running image: {.status.containerStatuses[0].image}{\"\\n\"}imageID: {.status.containerStatuses[0].imageID}{\"\\n\"}{end}"; kubectl -n mst get pvc podinfo-data -o jsonpath="PVC UID: {.metadata.uid}{\"\\n\"}"; kubectl -n mst get rs -o wide'
```

## 4.2 A konfiguráció módosítása

Nyisd meg a `deployment/deployment.yaml` fájlt egy szerkesztőben (pl. `nano deployment/deployment.yaml`), és a `### IMAGE ###` alatti sorban írd át a taget:

```yaml
          image: stefanprodan/podinfo:6.17.0
```

Mást ne módosíts. Ellenőrizd, hogy tényleg csak ez az egy sor változott:

```bash
ev T05-config-diff.txt 'git diff deployment/'
```

## 4.3 Előnézet: mit fog változtatni az apply?

```bash
ev T05-kubectl-diff.txt 'kubectl diff -k deployment/'
```

**Mire számíts:** a diff **csak a Deploymentet** érinti, és benne csak az `image:` sort. A PVC, a Service és a Namespace nem jelenik meg. Ez bizonyítja, hogy a frissítés a tárolóhoz nem nyúl. A `[exit code: 1]` itt **normális**: a `kubectl diff` 1-gyel jelzi, hogy talált eltérést.

## 4.4 Alkalmazás

```bash
ev T05-apply.txt 'kubectl apply -k deployment/ && kubectl -n mst rollout status deploy/podinfo --timeout=180s'
```

**Mire számíts:** a Deploymentnél `configured`, a többinél `unchanged`, majd `successfully rolled out`.

A port-forward megint megszakad: indítsd újra a második terminálban.

## 4.5 T05 – az új verzió ellenőrzése

```bash
ev T05-after-version.txt 'curl -sS -i http://127.0.0.1:9898/version'
```

```bash
ev T05-after-image.txt 'kubectl -n mst get deploy podinfo -o jsonpath="spec image: {.spec.template.spec.containers[0].image}{\"\\n\"}"; kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o jsonpath="{range .items[*]}pod: {.metadata.name} uid: {.metadata.uid}{\"\\n\"}running image: {.status.containerStatuses[0].image}{\"\\n\"}imageID: {.status.containerStatuses[0].imageID}{\"\\n\"}{end}"; kubectl -n mst get pvc podinfo-data -o jsonpath="PVC UID: {.metadata.uid}{\"\\n\"}"; kubectl -n mst get rs -o wide; kubectl -n mst rollout history deploy/podinfo'
```

**Mire számíts:**
- `/version` → `"version":"6.17.0"`
- running image `…podinfo:6.17.0`, és **más** imageID (digest), mint a `T05-before-image.txt`-ben
- **ugyanaz** a PVC UID
- két ReplicaSet: a régi 0 Poddal, az új 1-gyel

## 4.6 T06 – az eredeti rekord a frissítés után

```bash
ev T06-store-get.txt 'curl -sS -o evidence/T06-readback.bin -w "HTTP %{http_code}, %{size_download} bytes\n" http://127.0.0.1:9898/store/$HASH && cmp evidence/T03-expected-record.txt evidence/T06-readback.bin && echo "MATCH: frissites utan is bajtrol bajtra egyezik" && sha256sum evidence/T03-expected-record.txt evidence/T06-readback.bin'
```

Végül még egy ismételt apply, hogy a frissített állapot is stabil legyen:

```bash
ev T06-apply-again-idempotent.txt 'kubectl apply -k deployment/; kubectl diff -k deployment/ && echo "NINCS ELTERES"'
```

## 4.7 Commit és tag: így választható ki a verzió

```bash
git add deployment/ evidence/ && git commit -m "Frissites: podinfo 6.14.1 -> 6.17.0 (T05-T06)"
```

Opcionálisan jelöld meg tagekkel a két állapotot. A 6.14.1-es állapot az ezt megelőző commit:

```bash
git tag podinfo-6.17.0 && git tag podinfo-6.14.1 HEAD~1
```

A beszámolóban ezt írd le:
- **Új telepítés 6.17.0-val (alapeset):** a fő ág aktuális állapota.
- **Új telepítés 6.14.1-gyel:** `git checkout podinfo-6.14.1`, **csak friss, üres clusterbe / új PVC-re**.
- **Meglévő, már frissített adaton** tilos a régi verziót elindítani.

## Ellenőrzőlista

- [ ] A `git diff` csak az image sort mutatja
- [ ] A `kubectl diff` csak a Deploymentet érinti
- [ ] `/version` 6.14.1 → 6.17.0, és az imageID is megváltozott
- [ ] A PVC UID mindvégig ugyanaz (T03, T04, T05 előtte és utána)
- [ ] `T06-store-get.txt`: `MATCH`, `exit code: 0`

## Hibakeresés

| Tünet | Mit nézz meg |
|---|---|
| A `/version` még mindig 6.14.1 | Valóban elmentetted a fájlt? `kubectl -n mst get deploy podinfo -o yaml \| grep image:`. Esetleg a régi port-forward a régi Podra mutat: indítsd újra. |
| A rollout elakad, a Pod `ContainerCreating` | `kubectl -n mst describe pod ...` Events; volume-csatolási vagy image pull hiba |
| `CrashLoopBackOff` az új verzióval | `kubectl -n mst logs deploy/podinfo --previous` |

**Következő:** [05-beadas.md](05-beadas.md)
