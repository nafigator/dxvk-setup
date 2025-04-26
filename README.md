# dxvk-setup
DXVK setup

# Usage
```shell
curl -H 'Cache-Control: no-cache, no-store' \
  -s https://raw.githubusercontent.com/nafigator/dxvk-setup/refs/heads/overrides/setup.sh | \
WINE=/usr/bin/wine \
WINEPREFIX=~/.local/share/games/my-pfx \
bash
```