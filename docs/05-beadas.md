# 05 – Beszámoló és beadás (C5)

**Cél:** a `report.md` kitöltése a saját bizonyítékaid alapján, majd a `MST_CFXLIQ_A.zip` elkészítése.

## 5.1 A report.md kitöltése

A `report.md` már tartalmazza a kiírás 8. pontjában előírt fejezeteket, `TODO` jelölésekkel. Haladj végig rajta:

1. **Minden számot és azonosítót a bizonyítékfájlokból másolj ki:** verziók, Pod UID-k, PVC UID, hash, imageID. Ne fejből írd.
2. Az ellenőrzési táblázat minden sorában hivatkozz a konkrét `evidence/…` fájlra.
3. A „Korlátok és tanulságok” fejezetbe **őszintén** írd le, mi nem ment elsőre és hogyan javítottad. Ha minden simán ment, azt is írd le: ez a kiírás szerint teljesen rendben van.
4. Ne másold be a teljes logokat. Elég 2–5 releváns sor, a többire hivatkozz.

Ha kész, átnézem, ha szeretnéd: a tartalmat ellenőrzöm a kiírás szempontjai alapján, de a szöveget te írod.

Hasznos, gyors ellenőrzés, hogy minden `cmp` sikeres volt-e:

```bash
grep -H -E "MATCH|exit code" evidence/T0*-store-get.txt
```

## 5.2 Még egyszer: semmi titkos adat ne kerüljön be

```bash
grep -rniE "password|token|secret|BEGIN .*PRIVATE KEY|client-key-data" --exclude-dir=.git . || echo "OK: nincs talalat"
```

A kubeconfig a `~/.kube/config` fájlban van, a repón kívül; a `.gitignore` is kizárja.

## 5.3 A ZIP elkészítése

A kiírás szerint kibontás után **egyetlen projektkönyvtárat** kell látni. A `git archive` pontosan a commitolt fájlokat csomagolja, egy közös előtaggal:

```bash
git status --short   # üres legyen: minden be van commitolva
```

```bash
git archive --format=zip --prefix=mst-project/ -o ~/MST_CFXLIQ_A.zip HEAD
```

```bash
unzip -l ~/MST_CFXLIQ_A.zip
```

Ellenőrizd a listában: `mst-project/README.md`, `mst-project/report.md`, `mst-project/deployment/…`, `mst-project/evidence/…`.

Próbaként bontsd ki egy ideiglenes mappába, és nézd meg, hogy a README alapján érthető-e:

```bash
rm -rf /tmp/zipcheck && mkdir /tmp/zipcheck && unzip -q ~/MST_CFXLIQ_A.zip -d /tmp/zipcheck && ls /tmp/zipcheck/mst-project
```

## 5.4 Takarítás – csak a beadás UTÁN

Lásd a README „Takarítás” részét. Amíg a beadás nincs elfogadva, **hagyd futni** a clustert: ha az oktató élő bemutatót kér, meg tudod mutatni.

## 5.5 Tovább a haladó részre (opcionális, +30 pont)

Az alapfeladat lezárása után következhet:
- **A1/A2 – Valkey cache és kiesés/helyreállás:** külön Deployment és Service, `--cache-server=tcp://valkey:6379`
- **A3 – Mentés és visszaállítás új PVC-re**
- **A4 – `verify.sh` PASS/FAIL tesztscript és az idempotencia bizonyítása**

Szólj, ha idáig eljutottál, és megírom ezekhez is az útmutatót.
