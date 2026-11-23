# HTTPS for sign-up and sign-in

The launcher sends a player's username and password to the web server
(`web-server`). Over plain HTTP anyone on the way can read them, and security
software such as Bitdefender blocks the request ("an attempt to send your
password unencrypted"). HTTPS fixes both.

HTTPS is **optional**. It is off until you turn it on, and the plain HTTP port
(54993) keeps working beside it either way:

- **A server only you or your household use, on your own network:** you can
  leave it off.
- **A server players reach over the internet:** turn it on. It costs nothing.

The launcher tries HTTPS (port 443) first and falls back to plain HTTP only for
servers that don't offer it, warning the player when it does. Once a server has
answered over HTTPS, the launcher won't fall back to HTTP for it again.

## The free way: Let's Encrypt, built in

The web server can fetch a free [Let's Encrypt](https://letsencrypt.org/)
certificate by itself and renew it before it runs out (every ~60 days). You
need two things.

### 1. A name for your server

Certificates are issued for names, not bare IP addresses. If you don't own a
domain, take a free one from a dynamic DNS service, which also follows your
home IP address when it changes:

- [Dynu](https://www.dynu.com/) — free, run their update client or set it up
  in your router
- [DuckDNS](https://www.duckdns.org/) — free, `yourname.duckdns.org`
- Many routers have dynamic DNS built in (look for "DDNS" in its settings).

If you own a domain, add an `A` record pointing at your public IP instead.

Check it: `nslookup play.example.com` should print your public IP address.

### 2. Port 443 reachable from the internet

Let's Encrypt proves you control the name by connecting to it on **port 443**
(the TLS-ALPN-01 check). Nothing else needs to be open for it; port 80 is not
used.

- **Router:** forward TCP 443 to the server machine, next to 54992-54994.
- **Windows:** allow the port in the firewall (PowerShell, as administrator):
  `New-NetFirewallRule -DisplayName "XIVLegacy HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow`
- **Linux:** ports below 1024 need privileges. Either give the binary the
  right once, `sudo setcap cap_net_bind_service=+ep ./web-server`, or listen
  on another port (`port = 8443` below) and forward the router's **external
  443** to internal 8443. The outside port must be 443; the inside one can be
  anything.

### 3. Turn it on

In `settings/web.toml`:

```toml
[server]
bind_ip = "0.0.0.0"

[tls]
domains = ["play.example.com"]
contact = ["you@example.com"]   # optional: Let's Encrypt's expiry warnings
```

Restart the web server. Its log shows `HTTPS listening (Let's Encrypt)`, then
a `certificate:` line once the certificate arrives (a few seconds). The
account and certificate are kept in `data/acme` (`cache_dir`), so restarts
don't ask for a new one. Back that folder up with the rest of `data/`.

Check from outside your network (a phone on mobile data works):
`https://play.example.com/healthz` should show `ok` with a padlock.

**Trying it out first:** `staging = true` uses Let's Encrypt's test service,
which has generous limits but whose certificates nothing trusts. Set it back to
`false` and delete `data/acme` when it works. The real service allows 5
certificates per name per week, so a misconfigured server that keeps restarting
can lock itself out for a few days.

## Using a certificate you already have

If you already get certificates another way (also free: certbot, acme.sh,
win-acme, or your hosting panel), point the server at the PEM files instead:

```toml
[tls]
cert_file = "/etc/letsencrypt/live/play.example.com/fullchain.pem"
key_file  = "/etc/letsencrypt/live/play.example.com/privkey.pem"
```

`cert_file` is the full chain (your certificate first, then the
intermediates). The server rereads both files every 12 hours, so a renewal
needs no restart. When `cert_file` is set, `domains` is ignored.

## Settings

All in `[tls]` of `settings/web.toml` (defaults in `settings/default/web.toml`):

| Key | Default | Meaning |
|---|---|---|
| `port` | `443` | HTTPS port. Launchers try 443. |
| `domains` | `[]` | Names for a Let's Encrypt certificate. Setting one turns HTTPS on. |
| `contact` | `[]` | Email addresses for Let's Encrypt notices. |
| `cache_dir` | `"data/acme"` | Where the Let's Encrypt account and certificate live. |
| `staging` | `false` | Use Let's Encrypt's test service. |
| `cert_file`, `key_file` | `""` | Your own certificate (PEM). Setting `cert_file` turns HTTPS on. |

HTTPS listens on the same `bind_ip` as the plain HTTP port.

## Troubleshooting

- **`certificate: order: ... rejectedIdentifier`:** the name isn't a real
  public name (typo, or an internal name like `.lan`).
- **`... connection` or `timeout` errors:** Let's Encrypt couldn't reach port
  443. Check the router forward, the firewall, and that the name resolves to
  your current public IP. Some home internet providers block incoming 443; use
  your own certificate from a DNS check (certbot or acme.sh with your DNS
  provider's plugin) instead.
- **`rateLimited`:** wait out the hour or week it names, and test with
  `staging = true` meanwhile.
- **Players still see the warning:** they need launcher 0.1.33 or later; older
  launchers only speak HTTP.
