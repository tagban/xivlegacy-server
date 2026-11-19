# status

`GET /status` on the web server (port 54993): who is playing, for server status
pages such as moghouse.cc. Public, read-only, cacheable for 30 seconds, and
callable from any website (`Access-Control-Allow-Origin: *`).

```json
{
  "game": "FINAL FANTASY XIV 1.23b",
  "world": "Fernehalwes",
  "players_online": 2,
  "recent": [
    { "name": "Lyse Hext", "city": "Limsa Lominsa", "city_id": "limsa", "online": true,  "zone": "Limsa Lominsa Upper Decks", "last_active": "2026-10-25T21:04:11Z" },
    { "name": "Raya O Senna", "city": "Gridania",   "city_id": "gridania", "online": false, "zone": "Central Shroud", "last_active": "2026-10-25T19:30:02Z" }
  ],
  "updated": "2026-10-25T21:10:00Z"
}
```

- `players_online`: characters in the world now (the world server's
  `world_sessions`).
- `recent`: up to 10 characters, those online first, then by when they last
  entered or left the world.
- `zone`: where the character is, or was when they left: the zone's place
  name from `server_zones` (empty if unknown).
- `city` / `city_id`: the starting city (`limsa`, `gridania`, `uldah`), for a
  flag next to the name.

The FFXI server's exporter uses the same shape (`game`: "FINAL FANTASY XI",
`city_id`: `sandoria`, `bastok`, `windurst`), so one website plugin shows both.
