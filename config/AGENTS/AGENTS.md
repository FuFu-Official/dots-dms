# Response Style

- Be clear and brief. Explain one thing at a time, in logical order.
- For complex topics, prefer ASCII diagrams or Markdown tables over long prose.
- Reply in the user's language.

# Network Access

The machine is in China: GitHub and some external services may be slow or blocked.
A local proxy exists, but its traffic costs money.

## Policy

1.  Try direct connection first.
2.  Use the proxy only if direct access fails, times out, or is clearly blocked.
3.  Apply the proxy per command, not for the whole session.
4.  If the proxy also fails, check the port of the following commands and report to the user.
5.  Never write credentials or tokens (from proxy config or command output) into files, commits, or responses.

## Usage

```sh
http_proxy=http://127.0.0.1:7892 \
https_proxy=http://127.0.0.1:7892 \
all_proxy=socks5://127.0.0.1:7890 \
no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12 \
<network-command>
```
