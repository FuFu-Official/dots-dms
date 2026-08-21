# Network Access

This machine is in China, so direct access to GitHub and some other external
services may be slow or fail. A local Clash-Party instance is available, but
proxy traffic may cost money.

## Policy

- Try the direct connection first.
- Use the proxy only when direct access fails, times out, or is clearly
  blocked.
- Prefer a proxy for the single network command rather than enabling it for
  the whole shell session.
- Keep local addresses and package registries that work directly off the
  proxy.
- Never put proxy URLs, tokens, or command output containing credentials into
  files, commits, or the response.
- Do not assume that a failed request means the service is unavailable. Retry
  once with the proxy before reporting the failure.

## Available Proxy

The Fish helpers are defined in `~/.config/fish/conf.d/00-general.fish`:

```fish
proxy_on   # Enable the local proxy in the current Fish session
proxy_off  # Remove the proxy variables from the current Fish session
```

Their current endpoints are:

```text
HTTP/HTTPS: http://127.0.0.1:7892
SOCKS5:     socks5://127.0.0.1:7890
No proxy:   localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12
```

These environment variables also work with Bash, Zsh, and most CLI tools:

```sh
http_proxy=http://127.0.0.1:7892 \
https_proxy=http://127.0.0.1:7892 \
all_proxy=socks5://127.0.0.1:7890 \
no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12 \
<network-command>
```

## Procedure

1. Run the requested network command without a proxy.
2. If it fails because of timeout or connectivity, check whether the local
   proxy is listening on ports `7892` or `7890`.
3. Retry the command with the proxy environment variables above, preferably
   scoped to that command.
4. If the proxy endpoint is unavailable, inspect the local Clash-Party
   configuration or test another configured local port. Do not invent remote
   proxies.
5. Report which connection method worked. Do not repeatedly retry a failing
   endpoint.

When using `proxy_on`, run `proxy_off` after the network work is complete if
the shell session will continue to be used for unrelated commands.
