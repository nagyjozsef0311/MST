# 03 – Rekord írása és a Pod lecserélése (T03, T04 · C3)

**Cél:** írj be egy egyedi rekordot, olvasd vissza bájtra pontosan, majd cseréld le a Podot (új UID), és bizonyítsd, hogy ugyanaz a PVC ugyanazokat a bájtokat szolgálja ki.

Előfeltétel: a második terminálban fut a `kubectl -n mst port-forward svc/podinfo 9898:9898`, az elsőben pedig:

```bash
cd ~/MST && source scripts/ev.sh
```

---

## Elmélet röviden

**Tartalomcímzett tárolás.** A podinfo `POST /store` végpontja a kapott bájtokat egy fájlba írja a `--data-path` könyvtárba (nálunk `/data`). A fájl neve a tartalom **SHA-1 hash**-e. Ugyanaz a tartalom mindig ugyanazt a nevet kapja, más tartalom mást. Ezért egy jól ismert hash címként működik. **Integritás-ellenőrzésre viszont nem elég:** azt, hogy a visszakapott bájtok egyeznek-e, külön kell ellenőrizni (`cmp`, `sha256sum`). A kiírás ezt kifejezetten kéri. A SHA-1 ütközés gyakorlatban is előállítható, ezért ellenőrző összegnek inkább SHA-256-ot használunk.

**Mi marad meg és mi nem?**

| Hol van az adat | Pod törlése után |
|---|---|
| A container írható rétege | **elvész** |
| `emptyDir` volume | **elvész** (a Poddal együtt él) |
| PVC → PV | **megmarad** (a PVC külön Kubernetes objektum) |

**Mi történik `kubectl delete pod` után?** A ReplicaSet controller azt látja, hogy 0 Pod fut, pedig 1 kellene. Erre létrehoz egy **új** Podot: új nevet, új UID-t és új IP-t kap, de ugyanarra a PVC-re hivatkozik. Ez a *reconcile loop* működés közben. Egy sima újraindítás ugyanazt a Podot (és UID-t) tartaná meg, ezért nem fogadható el.

---

## 3.1 A tesztrekord elkészítése

Két sor, ASCII szöveg, benne az azonosítód. A `printf` pontosan ezeket a bájtokat írja ki, a végén egy sortöréssel.

```bash
mkdir -p testdata && printf 'MST-ID=CFXLIQ\nMST-NOTE=Track A podinfo persistence test record, line 2\n' > testdata/record.txt
```

Mentsd el az **elvárt** tartalmat és az ellenőrző összegeit *mielőtt* bármit visszaolvasol:

```bash
cp testdata/record.txt evidence/T03-expected-record.txt
```

```bash
ev T03-expected.txt 'cat -A testdata/record.txt; wc -c testdata/record.txt; sha256sum testdata/record.txt; sha1sum testdata/record.txt'
```

A `cat -A` láthatóvá teszi a rejtett karaktereket: a sorvéget `$` jelöli. Így a bizonyítékból is kiderül, pontosan milyen bájtok vannak a fájlban.

```bash
git add testdata/ evidence/ && git commit -m "T03: elvart tesztrekord rogzitve"
```

## 3.2 T03 – írás

```bash
ev T03-store-post.txt 'curl -sS -i --data-binary @testdata/record.txt http://127.0.0.1:9898/store'
```

> A `--data-binary` pontosan a fájl bájtjait küldi. A `-d` kivenné a sortöréseket, ezért azt ne használd.

**Mire számíts:** HTTP 2xx válasz és egy `{"hash":"…"}` JSON. Hasonlítsd össze a hash-t a `T03-expected.txt`-ben lévő `sha1sum` értékkel; meg kell egyezniük. Ez a tartalomcímzés bizonyítéka.

Másold ki a hash-t, és tedd elérhetővé változóként. **Jegyezd fel máshova is**, ezt fogod használni a feladat végéig:

```bash
export HASH=ide_masold_a_hash_erteket
```

```bash
echo "$HASH" > evidence/T03-hash.txt
```

## 3.3 T03 – visszaolvasás és bájtszintű összehasonlítás

```bash
ev T03-store-get.txt 'curl -sS -o evidence/T03-readback.bin -w "HTTP %{http_code}, %{size_download} bytes\n" http://127.0.0.1:9898/store/$HASH && cmp testdata/record.txt evidence/T03-readback.bin && echo "MATCH: bajtrol bajtra egyezik" && sha256sum testdata/record.txt evidence/T03-readback.bin'
```

**Mire számíts:** `HTTP 200`, `MATCH: ...`, a két `sha256sum` pedig azonos, és az `[exit code: 0]` sor zárja. Ha a `cmp` eltérést talál, kiírja, melyik bájtnál, és a kilépési kód nem 0.

## 3.4 A tartós tároló azonosítása

Rögzítsd, *melyik* tároló tartalmazza az adatot. A PVC UID-jét a T04 és a T06 után újra ellenőrizzük.

```bash
ev T03-storage-identity.txt 'kubectl -n mst get pvc podinfo-data -o custom-columns=PVC:.metadata.name,UID:.metadata.uid,STATUS:.status.phase,VOLUME:.spec.volumeName,CLASS:.spec.storageClassName; kubectl get pv $(kubectl -n mst get pvc podinfo-data -o jsonpath="{.spec.volumeName}") -o custom-columns=PV:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy,HOSTPATH:.spec.hostPath.path,LOCALPATH:.spec.local.path'
```

Nézz bele a Podból a `/data` könyvtárba. A fájl neve a hash, a tulajdonosa `100 101`:

```bash
ev T03-data-dir.txt 'kubectl -n mst exec deploy/podinfo -c podinfo -- ls -ln /data'
```

**Kiegészítő tanulság:** a PV a kind node fájlrendszerén egy valódi könyvtár. A node egy Docker container, így bele tudsz nézni. A `HOSTPATH`/`LOCALPATH` oszlopból vett útvonalat írd be a `<UTVONAL>` helyére:

```bash
ev T03-node-path.txt 'docker exec mst-control-plane ls -ln <UTVONAL>'
```

### Opcionális, de ajánlott: reclaim policy átállítása Retain-re

A kind `standard` StorageClass-a `Delete` reclaim policyt használ: ha valaki törli a PVC-t, a PV és az adat is törlődik. A `Retain` beállítással a PV megmarad, ha a PVC véletlenül törlődne. Ez nem kötelező, de jó szokás, és a beszámolóban is érdemes megemlíteni.

```bash
ev T03-pv-retain.txt 'kubectl patch pv $(kubectl -n mst get pvc podinfo-data -o jsonpath="{.spec.volumeName}") -p "{\"spec\":{\"persistentVolumeReclaimPolicy\":\"Retain\"}}"; kubectl get pv'
```

## 3.5 T04 – a Pod lecserélése

**a) A régi Pod adatai:**

```bash
ev T04-before.txt 'kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o custom-columns=POD:.metadata.name,UID:.metadata.uid,IP:.status.podIP,IMAGE:.spec.containers[0].image,PVC:.spec.volumes[0].persistentVolumeClaim.claimName; kubectl -n mst get pvc podinfo-data -o jsonpath="PVC UID: {.metadata.uid}{\"\\n\"}"'
```

**b) Törlés, majd várakozás az újra:**

```bash
ev T04-replace.txt 'kubectl -n mst delete pod -l app.kubernetes.io/name=podinfo --wait=true && kubectl -n mst wait pod -l app.kubernetes.io/name=podinfo --for=condition=Ready --timeout=180s'
```

> A második terminálban lévő **port-forward ilyenkor megszakad**, mert egy konkrét Podhoz kötődött. Ez várható. Állítsd le (Ctrl+C), és indítsd újra ugyanazzal a paranccsal.

**c) Az új Pod adatai:**

```bash
ev T04-after.txt 'kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o custom-columns=POD:.metadata.name,UID:.metadata.uid,IP:.status.podIP,IMAGE:.spec.containers[0].image,PVC:.spec.volumes[0].persistentVolumeClaim.claimName; kubectl -n mst get pvc podinfo-data -o jsonpath="PVC UID: {.metadata.uid}{\"\\n\"}"'
```

**Mire számíts:** az új Pod neve, UID-je és IP-je **más**. Az image (`6.14.1`), a PVC neve és a **PVC UID-je ugyanaz**.

**d) Visszaolvasás az új Podból, ugyanazzal a hash-sel, ugyanazzal a fájllal összevetve.** Ha új terminált nyitottál, előbb: `export HASH=$(cat evidence/T03-hash.txt)`.

```bash
ev T04-store-get.txt 'curl -sS -o evidence/T04-readback.bin -w "HTTP %{http_code}, %{size_download} bytes\n" http://127.0.0.1:9898/store/$HASH && cmp evidence/T03-expected-record.txt evidence/T04-readback.bin && echo "MATCH: Pod-csere utan is bajtrol bajtra egyezik" && sha256sum evidence/T03-expected-record.txt evidence/T04-readback.bin'
```

```bash
git add evidence/ && git commit -m "T03-T04: rekord irasa, Pod csere, adatmegorzes igazolva"
```

## Ellenőrzőlista

- [ ] A `/store` által adott hash megegyezik a `sha1sum` értékkel
- [ ] A `T03-store-get.txt` és a `T04-store-get.txt` is `MATCH` és `exit code: 0`
- [ ] A `T04-before` és a `T04-after` szerint a Pod UID különböző, a PVC UID azonos

## Ha nem egyezik

Ne írd újra a rekordot! Előbb ellenőrizd:
1. Jó-e a `$HASH` értéke (`echo $HASH`).
2. A Pod tényleg a `podinfo-data` PVC-t csatolja-e: `kubectl -n mst describe pod -l app.kubernetes.io/name=podinfo | grep -A3 Volumes`.
3. Megvan-e a fájl: `kubectl -n mst exec deploy/podinfo -- ls -ln /data`.

**Következő:** [04-frissites.md](04-frissites.md)
