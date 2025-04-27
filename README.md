# dxvk-setup
DXVK setup fo Linux

# Usage

```shell
SYNOPSIS
       setup.sh [OPTIONS...]

OPTIONS
       -v, --version    Show script version
       -h, --help       Show this help message
       -d, --debug      Run script in debug mode

ENVIRONMENT
       WINEPREFIX       Defines wine prefix to install DXVK libs. By default installs into current dir.
       WINE             Defines path to wine binary. By default wine will be used from $PATH.
```

# Examples

<details>
  <summary>Installation into current dir</summary>

```shell
cd /home/user/.wine && setup.sh
```
</details>

<details>
  <summary>Installation into defined prefix with specific wine build</summary>

```shell
WINE=/home/user/.local/share/wine/bin/wine \
WINEPREFIX=/home/user/.wine \
setup.sh
```
</details>

<details>
  <summary>Remote script usage</summary>

```shell
curl -H 'Cache-Control: no-cache, no-store' \
  -s https://raw.githubusercontent.com/nafigator/dxvk-setup/refs/heads/main/setup.sh | \
WINE=/usr/bin/wine \
WINEPREFIX=~/.local/share/games/my-pfx \
bash
```
</details>
