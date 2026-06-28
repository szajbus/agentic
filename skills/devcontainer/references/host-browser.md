# Driving a headless Chrome on the host from the container

An **opt-in, dev-only** feature: let the in-container agent drive a headless
Chrome running on the **host** — e.g. to screenshot or visually check the
running dev app. Off by default; only wire it when asked, and tell the user
about the exposure (below).

## Topology (the "look at the dev app" case)

```
 container                         host
 ┌──────────────┐    CDP/ws    ┌──────────────────────────┐
 │ agent + tool │ ───────────► │ socat relay :9223        │
 │              │  gateway IP  │   └► Chrome CDP :9222     │
 └──────────────┘              │ Chrome ──HTTP──► app      │
        ▲                      │            localhost:PORT │
        │ app published        └──────────────────────────┘
        └─ 127.0.0.1:PORT (already there)
```

Two links:

1. **Container → Chrome control port.** The container reaches the host via
   `host.docker.internal` (compose maps it to `host-gateway`). Chrome's CDP only
   binds to the host's `127.0.0.1`, so a `socat` relay re-exposes it on a
   routable port.
2. **Chrome → app.** Chrome runs on the host and the dev app is already
   published on the host at `127.0.0.1:${PORT}`, so the agent just tells Chrome
   to load `http://localhost:${PORT}`. Nothing extra to wire.

(The harder "Wallaby/ephemeral test server" case is different — the app-under-
test lives in the container and a host browser can't reach it without publishing
a fixed test port. That's out of scope here; this is the dev-server case.)

## Why the relay + connect-by-IP (don't skip this)

Chrome's DevTools endpoint has two guards:

- The `/json/*` HTTP endpoints reject any `Host:` header that isn't an **IP
  literal or `localhost`** (anti-DNS-rebinding). So the container must connect
  using the **gateway IP**, not `host.docker.internal`. `bin/chrome-cdp`
  resolves the IP for you.
- The WebSocket upgrade checks `Origin`; launch Chrome with
  `--remote-allow-origins='*'` (bin/chrome-host does).

`--remote-debugging-address` (bind CDP to 0.0.0.0) was **removed** from Chrome,
which is why the `socat` relay is necessary rather than just binding wide.

## The two helper scripts

- **`bin/chrome-host`** — run on the **host**. Launches headless Chrome
  (`--remote-allow-origins='*'`, throwaway profile) and a `socat` relay on
  `0.0.0.0:9223 → 127.0.0.1:9222`. Needs `socat` (`brew install socat`) and a
  Chrome/Chromium (`CHROME_BIN` to override discovery). Ports via
  `CHROME_DEBUG_PORT` / `CHROME_RELAY_PORT`.
- **`bin/chrome-cdp`** — run in the **container**. Prints the reachable CDP base
  URL (`http://<gateway-ip>:9223`) and warns if Chrome isn't up.

Compose adds `extra_hosts: ["host.docker.internal:host-gateway"]` to the app
service (the `STACK:browser` block).

## Using it (example clients)

On the host:
```sh
bin/chrome-host        # leave running
```
In the container:
```sh
CDP=$(bin/chrome-cdp)  # e.g. http://192.168.65.1:9223
```
Then connect a CDP client and point it at the dev app (`http://localhost:$PORT`,
host-side). Pick whatever the container already has:

- **Playwright:** `browser = await chromium.connectOverCDP(process.env.CDP)`
- **puppeteer-core:** `puppeteer.connect({ browserURL: process.env.CDP })`
- **chrome-remote-interface:** `CDP({ host, port })` from the URL
- **No Node?** `websocat` is bundled in the image — speak CDP directly. The
  target's ws URL reports Chrome's own `127.0.0.1:<debug-port>`, which isn't
  reachable from the container, so rewrite the host to the relay. A screenshot:

  ```sh
  CDP=$(bin/chrome-cdp)                        # http://<gateway-ip>:9223
  relay=${CDP#http://}                         # <gateway-ip>:9223
  ws=$(curl -s "$CDP/json/new?http://localhost:$PORT" \
        | jq -r .webSocketDebuggerUrl | sed -E "s#127\.0\.0\.1:[0-9]+#$relay#")
  printf '%s\n' \
    '{"id":1,"method":"Page.captureScreenshot","params":{"format":"png"}}' \
    | websocat -n1 "$ws" \
    | jq -r 'select(.id==1)|.result.data' | base64 -d > shot.png
  ```

  Give the page a moment to render (or wait on `Page.loadEventFired`) before
  capturing.

## Security — call this out to the user

This deliberately opens a **browser-control channel on the host**, reachable from
the container (and, because the relay binds all interfaces, from the LAN while
it's running). A controlled browser can open `file://` and intranet URLs. It
runs counter to the rest of the setup's "no host access from the container"
stance. Keep it:

- **off by default** (don't generate it unless the user wants browser access),
- **dev-only**, on a trusted network,
- **transient** — `bin/chrome-host` runs in the foreground so it's obvious it's
  up; stop it (Ctrl-C) when done.
