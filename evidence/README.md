# evidence/ – a bizonyítékok tartalomjegyzéke

Minden `.txt` fájl a `scripts/ev.sh` `ev` függvényével készült. Minden bejegyzésben benne van az időpont, a pontos parancs, a teljes kimenet (stdout és stderr) és a kilépési kód. Az újrafuttatások hozzáfűződtek a fájlhoz, a korábbi (sikertelen) próbálkozások is megmaradtak. Az időpontok helyi idő szerint (CET, +01:00) szerepelnek.

| Fájl | Ellenőrzés | Tartalom |
|---|---|---|
| `ENV-host.txt` | környezet | OS, kernel, CPU, RAM, lemez |
| `ENV-tools.txt` | környezet | Docker, kind, kubectl, git, curl verziója (az első bejegyzés még a hibás kind binárissal készült) |
| `ENV-kind-hibas-letoltes.txt` | 9.2/1. probléma | a hibás kind bináris tünete |
| `C1-cluster-create.txt`, `C1-cluster-info.txt` | C1 | a cluster létrehozása, a node és a StorageClass |
| `C1-kustomize-render.txt` | C1 | a ténylegesen alkalmazott (renderelt) konfiguráció |
| `C1-apply-1.txt`, `C1-rollout.txt`, `C1-state.txt` | C1 | telepítés, rollout, állapot (PVC Bound, Pod Running) |
| `C1-init-log.txt`, `C1-app-log.txt` | C1 | az init container és a podinfo logja |
| `C1-apply-2-idempotent.txt` | C1 | ismételt apply: `unchanged`, üres diff |
| `T01-T02-readyz.txt`, `T01-T02-version.txt` | T01, T02 | HTTP elérés a hostról, port-forwardon keresztül |
| `C2-service-endpoints.txt` | C2 | Service, EndpointSlice, Pod IP |
| `C2-incluster-client.txt` | T02, C2 | kliens Pod: DNS-feloldás és HTTP a Service nevén |
| `C2-host-listening-ports.txt` | C2 | a hoston figyelő portok (csak loopback) |
| `T03-expected-record.txt` | T03 | az elvárt bájtok (a `testdata/record.txt` másolata) |
| `T03-expected.txt` | T03 | méret, SHA-256, SHA-1 |
| `T03-store-post.txt`, `T03-hash.txt` | T03 | írás és a kapott hash |
| `T03-store-get.txt`, `T03-readback.bin` | T03 | visszaolvasás, `cmp` |
| `T03-storage-identity.txt`, `T03-data-dir.txt`, `T03-node-path.txt` | C3 | a PVC/PV azonosítása, a fájl a Podban és a node-on |
| `T03-pv-retain.txt` | C3 | a PV reclaim policy átállítása Retain-re |
| `T04-before.txt`, `T04-after.txt` | T04 | Pod név, UID, IP, image, PVC UID csere előtt és után (két kísérlet) |
| `T04-replace.txt` | T04 | a Pod törlése és várakozás (1. kísérlet: timeout, 2.: sikeres) |
| `T04-debug.txt` | T04 | hibakeresés: describe, logok, események, az adat megléte a node-on |
| `T04-fix.txt` | T04 | a javítás: git diff, kubectl diff, apply |
| `T04-store-get.txt`, `T04-readback.bin` | T04 | visszaolvasás a csere után, `cmp` |
| `T05-before-version.txt`, `T05-before-image.txt` | T05 | a régi verzió, image és digest |
| `T05-config-diff.txt`, `T05-kubectl-diff.txt` | T05 | a konfigurációmódosítás és az előnézet |
| `T05-apply.txt` | T05 | a frissítés alkalmazása |
| `T05-after-version.txt`, `T05-after-image.txt` | T05 | az új verzió, image, digest, ReplicaSetek, rollout history |
| `T06-store-get.txt`, `T06-readback.bin` | T06 | visszaolvasás a frissítés után, `cmp` |
| `T06-apply-again-idempotent.txt` | T06, C1 | ismételt apply a frissítés után |
