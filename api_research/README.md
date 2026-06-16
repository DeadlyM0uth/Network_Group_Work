# API-исследование Matrix

**Выполнил:** Желанов Даниил

## Цель работы

Цель работы — проверить доступность основных Matrix Client-Server API endpoints с `access_token` и без него.

Проверяемые endpoints:

- `/_matrix/client/versions`
- `/_matrix/client/v3/login`
- `/_matrix/client/v3/account/whoami`
- `/_matrix/client/v3/joined_rooms`
- `/_matrix/client/v3/publicRooms`
- `/_matrix/client/v3/profile/{userId}`
- `/_matrix/client/v3/sync`
- `/_matrix/client/v3/rooms/{roomId}/messages`
- `/_matrix/client/v3/rooms/{roomId}/send/m.room.message/{txnId}`

## Подготовка

Целевой сервер доступен внутри Tailscale-сети.

- Tailscale IP: `100.83.165.96`
- Base URL: `https://messenger-server.tail9da30d.ts.net`
- Реализация homeserver: `Synapse/1.153.0`

Проверка доступности:

```powershell
tailscale ping 100.83.165.96
Test-NetConnection 100.83.165.96 -Port 443
````

## Первичная проверка API

### Проверка версий API

Команда:

```powershell
curl.exe -sS -i "https://messenger-server.tail9da30d.ts.net/_matrix/client/versions"
```

Результат сохранён в файл:

```text
results/01_versions.txt
```

Краткий результат:

```text
HTTP/1.1 200 OK
Server: Synapse/1.153.0
```

Вывод: endpoint `/_matrix/client/versions` доступен без авторизации и возвращает список поддерживаемых версий Matrix Client-Server API.

### Проверка способов авторизации

Команда:

```powershell
curl.exe -sS -i "https://messenger-server.tail9da30d.ts.net/_matrix/client/v3/login"
```

Результат сохранён в файл:

```text
results/02_login_flows.txt
```

Краткий результат:

```json
{
  "flows": [
    {
      "type": "m.login.password"
    },
    {
      "type": "m.login.application_service"
    }
  ]
}
```

Вывод: сервер поддерживает авторизацию по логину и паролю через `m.login.password`.
