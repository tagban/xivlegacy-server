# Running XIVLegacy Server on a Linux VPS

Everything needed to run the server on a small Linux machine: a cheap VPS with
1 GB of RAM and 1-2 x86-64 vCPUs is enough. It works on any current
distribution; it was tested on Debian 12 and Alpine 3.22 (see
[Tested](#tested) below).

| File | What it is |
| --- | --- |
| `install.sh` | One-time setup: MariaDB, database + user, service user, services, firewall, swap, the `xiv` command |
| `xiv.sh` | Day-to-day control, installed as `xiv`: status, deploy, start/stop/restart, logs, backup, import, hold/release, setgm, sql. The Linux twin of the NUC's `ops\xiv.cmd` |
| `mariadb-small.cnf` | MariaDB sized for 1 GB: 128 MB buffer pool, performance_schema off, 127.0.0.1 only |

## How the server gets there

A 1 GB VPS can't compile the server, so GitHub Actions builds it. The
[Linux server bundle](../../.github/workflows/linux-bundle.yml) workflow
builds the four servers as **static** x86-64 binaries (musl), so the same
download runs on Debian, Ubuntu, Rocky/Alma, Alpine or Arch with no glibc
version to match. It runs on every push to `develop`, and by hand for any
branch, tag or commit (GitHub > Actions > Linux server bundle > Run workflow).

Each run uploads one artifact, `xivlegacy-server-linux-x86_64-<commit>`,
holding `xivlegacy-server-linux-x86_64-<commit>.tar.gz` and its `.sha256`:

```
bin/                lobby-server, world-server, map-server, web-server (static)
scripts/lua/        content scripts
modules/            server modules
settings/default/   shipped settings
sql/                schema, game data, migrations (also built into the binaries:
                    the web server sets up an empty database at first start)
ops/linux/          these scripts
BUILD               commit, ref, build date
SHA256SUMS          checksums of every file
```

Artifacts are kept for 30 days. Downloading one needs a GitHub login, even
though the repository is public, so `xiv deploy <ref>` uses a token (step 4).

## Trial run, step by step

### 1. Get a VPS

Any provider with an x86-64 Linux VPS, 1 GB of RAM or more, and a public IPv4
address. **Pick Debian 12 or 13, or Ubuntu 24.04** if the provider lets you
choose: they ship MariaDB 10.11 or newer. Alpine and Arch work too. Rocky/Alma 9
ship MariaDB 10.5, which is older than anything the server has been tested on.
Add your SSH key when you create it.

If the provider has its own firewall (a "security group"), allow TCP **54993,
54994 and 54992** in, plus SSH. Nothing else needs to be open: the map server
(1989) and MariaDB (3306) listen on 127.0.0.1 only.

### 2. Put a server bundle on it

On the Mac (needs `gh`, already signed in), download the newest develop build
and copy it over:

```sh
sha=$(gh api repos/tagban/xivlegacy-server/commits/develop -q .sha)
gh run download -R tagban/xivlegacy-server -n xivlegacy-server-linux-x86_64-$sha -D ~/Downloads/xivlegacy-bundle
scp ~/Downloads/xivlegacy-bundle/xivlegacy-server-linux-x86_64-$sha.tar.gz* root@VPS:
```

### 3. Install

On the VPS, as root:

```sh
tar -xzf xivlegacy-server-linux-x86_64-*.tar.gz
cd xivlegacy-server-linux-x86_64-*/
./ops/linux/install.sh --address xiv.example.com     # or the VPS's IP address
```

`--address` is what players' launchers connect to (a host name pointing at the
VPS, or its IP). Without it, install.sh uses the VPS's own IPv4 address.
`--world-name` changes the world shown in the launcher (default Fernehalwes).

install.sh installs MariaDB with the small-memory config, creates the
`xivlegacy` database and user (the generated password is stored in
`/etc/xivlegacy/db.env`, root only, and never printed), creates the
`xivlegacy` service user, installs the services (systemd, or OpenRC on Alpine),
opens the ports in ufw or firewalld when either is running, adds a 1 GB swap
file if the VPS has under 2 GB of RAM, and installs this bundle and starts it.
At this point the server runs with an empty database. Running install.sh again
is safe: it keeps the password and `/etc/xivlegacy/xiv.conf`.

Check it:

```sh
xiv status
```

### 4. (Optional) Let it download builds itself

For `xiv deploy develop` (or any branch, tag, commit or `pr/123`) to download
builds, give it a GitHub token. A fine-grained token with **Public repositories
(read-only)** access and no permissions is enough:

```sh
install -m 600 /dev/stdin /etc/xivlegacy/github-token     # paste the token, then Ctrl-D
```

Without a token, copy bundles over as in step 2 and use
`xiv deploy --file xivlegacy-server-linux-x86_64-<sha>.tar.gz`.

### 5. Import a backup from the NUC

The NUC dumps the live database every night and before each deploy, to
`C:\Users\JohnServer\FFXIV\backups\live`. Copy the newest one to the VPS and
load it:

```sh
# on the Mac
f=$(ssh JohnServer@10.0.0.85 'dir /b /o-d C:\Users\JohnServer\FFXIV\backups\live' | head -n1 | tr -d '\r')
scp "JohnServer@10.0.0.85:C:/Users/JohnServer/FFXIV/backups/live/$f" .
scp "$f" root@VPS:

# on the VPS
xiv import xivlegacy-*.sql.gz
```

`xiv import` stops the servers, backs up the current database, loads the dump
and starts the servers again. It accepts dumps from a newer MariaDB than the
VPS has (the NUC runs 12.3).

To make yourself a GM on the copy: `xiv setgm "First Last" 4`.

### 6. Point a test client at it

In the XIVLegacy launcher, add a server with the VPS's address (the one given
to `--address`) and log in with a live account: the import brought the
accounts and characters over.

The live server stays on the NUC. Don't let players use the VPS copy unless you
mean to move: the two databases drift apart from the moment of the import.

## Everyday commands

```sh
xiv status                       # services, memory, players online, deployed build
xiv deploy                       # newest build of DEFAULT_REF (develop); backs up first,
                                 #   rolls back to the previous build if the new one doesn't come up
xiv deploy feat/my-branch        # a branch, tag, commit or pr/123 (needs its CI build)
xiv deploy --file bundle.tar.gz  # a bundle copied here by hand
xiv logs map -n 200              # web, lobby, world, map
xiv restart
xiv stop                         # also keeps it from starting at boot, until 'xiv start'
xiv backup                       # gzip'd dump in /var/backups/xivlegacy (14 days, newest 7 always kept)
xiv import dump.sql.gz
xiv hold "trying something"      # deploys and imports need --force until 'xiv release'
xiv setgm "First Last" 4
xiv sql "SELECT name FROM characters"
```

A branch other than develop needs a CI build before `xiv deploy` can find it:
run the Linux server bundle workflow for it (Actions tab, Run workflow, `ref`).

## Where things are

| Path | What |
| --- | --- |
| `/etc/xivlegacy/xiv.conf` | Address, world name, ports, log level, default ref. Edit, then `xiv restart` |
| `/etc/xivlegacy/db.env` | The database URL with its password (0600, root only) |
| `/etc/xivlegacy/github-token` | Optional, for `xiv deploy <ref>` |
| `/etc/xivlegacy/settings/` | Extra server settings copied in at every start (`modules.toml`, `commands.toml`, `bugreport.toml`, `jail.toml`...). `<name>.extra.toml` is appended to the generated `web`, `lobby`, `world`, `map` or `servers` file |
| `/opt/xivlegacy/releases/<sha>` | Installed bundles (the 5 newest); `/opt/xivlegacy/current` points at the running one |
| `/var/lib/xivlegacy` | The servers' working folder: generated settings, `data/` (bug reports) |
| `/var/backups/xivlegacy` | Database dumps |
| `/var/lib/xivlegacy-ops` | `xiv`'s state and log (`xiv.log`) |
| Logs | `journalctl -u xivlegacy-map` (systemd) or `/var/log/xivlegacy/*.log` (OpenRC); `xiv logs` reads either |

Services: `xivlegacy-web`, `-lobby`, `-world`, `-map`, grouped by
`xivlegacy.target` on systemd. The web server starts first and sets up or
updates the database; the others wait for it. A crashed server restarts by
itself, up to 5 times an hour.

## Differences from the NUC

- One instance per machine (the NUC runs live plus two test slots).
- The NUC builds from source; the VPS installs CI builds.
- On the NUC a crash restarts all four servers; here only the one that crashed
  restarts.
- `hold` blocks deploys and imports, since there's no nightly reset to skip.
- No nightly update yet; run `xiv deploy` when you want one.

## If something goes wrong

- `xiv status` and `xiv logs` first.
- **"no Linux build of ... yet"**: the commit has no CI bundle. Run the
  workflow for it, or wait for the develop push build to finish.
- **A deploy didn't come up**: `xiv deploy` puts the previous build back and
  says which backup it took before. The database is not rolled back
  automatically: `xiv import /var/backups/xivlegacy/<that file>` does that.
- **MariaDB won't start after install**: `journalctl -u mariadb` (or
  `/var/log/mysql`); the small-memory settings are in
  `/etc/mysql/mariadb.conf.d/90-xivlegacy.cnf` (Debian/Ubuntu) or
  `/etc/my.cnf.d/90-xivlegacy.cnf` (others).

## Tested

See the pull request that added this folder for the measurements: fresh
1 GB VMs, the live database imported, test clients logged in.
