# 01 – A környezet előkészítése

**Cél:** egy frissen telepített Linux laptopon legyen Docker Engine, `kubectl` és `kind`, a verzióik pedig legyenek rögzítve.

A parancsok **Ubuntu 24.04 LTS**-re vonatkoznak. Ha más disztribúciód van (Fedora, Debian, Mint, …), szólj, és átírom ezt a fejezetet.

---

## Elmélet röviden

**Container vs. VM.** A container nem virtuális gép. Egy közönséges Linux folyamat, amelyet a kernel *namespace*-ekkel elszigetel: saját fájlrendszert, hálózatot és folyamatlistát lát. A *cgroup*-ok korlátozzák az erőforrásait. Saját kernele nincs, a hostét használja, ezért indul el másodpercek alatt.

**Image.** Az image a container fájlrendszerének csak olvasható sablonja, rétegekből épül fel. Neve például `stefanprodan/podinfo:6.14.1`: ez *registry/repó:tag*. A tag csak egy címke, és átállítható. A *digest* (`sha256:…`) a tartalom ujjlenyomata, az nem változhat meg. Ezért a `latest` tag tilos: nem tudnád, mit futtatsz.

**Kubernetes.** A Kubernetes egy *deklaratív* rendszer. Nem azt mondod meg neki, hogy „indíts el egy containert”, hanem azt írod le, hogy „ennek kell futnia” (YAML). A *controllerek* folyamatosan összevetik a leírt állapotot a valóssal, és ha eltérést látnak, kijavítják. Ezt *reconcile loop*-nak hívják, és erre épül a 03. fejezet Pod-cseréje.

**kind** = *Kubernetes IN Docker*. Egy teljes Kubernetes node-ot futtat egy Docker containerben. Egy paranccsal létrehozható és eldobható, ezért laborhoz ideális. Élesben ugyanezek a manifestek egy valódi clusteren is futnának.

**kubectl.** A Kubernetes API parancssoros kliense. A verziója legfeljebb egy minor verzióval térhet el a clusterétől (*version skew policy*).

---

## 1.1 Alapcsomagok

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y ca-certificates curl git diffutils
```

## 1.2 Docker Engine (a Docker hivatalos apt repójából)

Az Ubuntu saját `docker.io` csomagja helyett a Docker hivatalos repóját használjuk, mert az frissebb, és ugyanazt dokumentálja a hivatalos leírás. Forrás: https://docs.docker.com/engine/install/ubuntu/

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
```

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Hogy ne kelljen minden parancs elé `sudo`, add hozzá magad a `docker` csoporthoz:

```bash
sudo usermod -aG docker "$USER"
```

Ezután **jelentkezz ki és be** (vagy indítsd újra a gépet), hogy a csoporttagság érvényes legyen.

> **Biztonsági megjegyzés a beszámolóhoz:** a `docker` csoport tagja gyakorlatilag root jogot kap a hoston, mert bármilyen containert indíthat, akár a host fájlrendszerét is felcsatolva. Egyfelhasználós laborgépen ez elfogadható, éles szerveren nem. Ilyen esetre való a *rootless Docker*.

Próba:

```bash
docker run --rm hello-world
```

## 1.3 kubectl

Forrás: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

```bash
cd /tmp && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
```

Ellenőrizd a letöltött fájl hash-ét. Ez a *supply chain* biztonság legegyszerűbb formája: azt telepíted-e, amit a kiadó közzétett. Az elvárt kimenet: `kubectl: OK`.

```bash
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
```

```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && cd ~
```

## 1.4 kind

Először kérdezd le a legfrissebb stabil kiadás számát. A GitHub a `/releases/latest` címet átirányítja a legújabb tagre, ebből olvassuk ki:

```bash
export KIND_VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/kubernetes-sigs/kind/releases/latest | sed 's#.*/tag/##')
```

```bash
echo "$KIND_VERSION"
```

Ennek valami `v0.NN.N` alakú értéket kell kiírnia. Ha üres, vagy `vX.Y.Z`-t látsz, **ne menj tovább**. A kiadási jegyzetben (https://github.com/kubernetes-sigs/kind/releases) az is szerepel, melyik Kubernetes verziót futtatja alapból a kind.

> A `curl -f` kapcsoló fontos: hibás URL esetén (HTTP 404) hibával kilép, ahelyett hogy a „Not Found” hibaoldalt csendben elmentené fájlként.

```bash
cd /tmp && curl -fLo kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
```

```bash
curl -fLo kind.sha256sum "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64.sha256sum"
```

```bash
echo "$(cut -d' ' -f1 kind.sha256sum)  kind" | sha256sum --check
```

```bash
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind && cd ~
```

## 1.5 A repó klónozása

```bash
git clone -b claude/jolly-curie-82x1n3 https://github.com/nagyjozsef0311/MST.git ~/MST
```

```bash
cd ~/MST
```

Ha még nem tetted meg, állítsd be a nevedet és az e-mail címedet a commitokhoz:

```bash
git config --global user.name "A Neved"
```

```bash
git config --global user.email "te@example.com"
```

## 1.6 BIZONYÍTÉK: futtatási környezet (report.md: „Futtatási környezet”)

```bash
source scripts/ev.sh
```

```bash
ev ENV-host.txt 'uname -a; cat /etc/os-release | head -4; nproc; free -h; df -h /'
```

```bash
ev ENV-tools.txt 'docker version; kind version; kubectl version --client; git --version; curl --version | head -1'
```

## Ellenőrzőlista

- [ ] A `docker run --rm hello-world` sudo nélkül lefut
- [ ] Mindkét `sha256sum --check` kimenete `OK`
- [ ] Megvan az `evidence/ENV-host.txt` és az `evidence/ENV-tools.txt`

## Gyakori hibák

| Tünet | Ok | Megoldás |
|---|---|---|
| `permission denied ... docker.sock` | még nincs érvényben a csoporttagság | ki- és bejelentkezés |
| `sha256sum: WARNING: 1 computed checksum did NOT match` | hibás vagy félbeszakadt letöltés | töröld és töltsd le újra |
| `kind: command not found` | nincs a PATH-ban | `ls -l /usr/local/bin/kind` |
| `/usr/local/bin/kind: line 1: Not: command not found` | a letöltött „bináris” valójában egy `Not Found` szöveg, mert hibás volt a verziószám (pl. `vX.Y.Z` maradt benne) | `file /usr/local/bin/kind` → „ELF 64-bit” kell legyen; töltsd le újra a fenti `KIND_VERSION` lépéssel |
| `[exit code: 127]` vagy `no such file` a 02. fejezetben | nem a repó gyökerében vagy (`~` helyett `~/MST` kell) | `cd ~/MST` |

**Következő:** [02-telepites.md](02-telepites.md)
