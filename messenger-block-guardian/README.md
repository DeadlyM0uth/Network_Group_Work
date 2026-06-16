# Messenger Block Guardian

Блокировка Matrix-мессенджера (Synapse) в Tailscale на Unix/Linux-хосте.

## Функционал

Скрипт `block_guardian.sh` делает три вещи:

1. **iptables** — DROP исходящего TCP/UDP к IP Matrix-сервера (цепочка `LAB_BLOCK_MESSENGER`)
2. **ip route blackhole** — недостижимый маршрут к заблокированному адресу
3. **Мониторинг** — каждые 2 с логирует попытки подключения клиента (`ss` + `logs/block_guardian.log`)

Опция `--kill-clients` завершает процесс клиента при обнаружении соединения.

## Использование

```bash
chmod +x block_guardian.sh

sudo ./block_guardian.sh                    # блок мессенджера (по умолчанию)
sudo ./block_guardian.sh --kill-clients     # + kill клиента
sudo ./block_guardian.sh --all-peers        # все peer IP из tailscale status
sudo ./block_guardian.sh --all-tailnet      # весь 100.64.0.0/10
sudo ./block_guardian.sh --stop             # снять блокировку
```

## Настройка

В скрипте или через аргументы:

```bash
SERVER_HOST="messenger-server.tail9da30d.ts.net"
sudo ./block_guardian.sh --server-ip 100.83.165.96
```

## Требования

root, bash, iptables, iproute2, ss, tailscale CLI.
