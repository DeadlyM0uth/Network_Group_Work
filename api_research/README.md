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
```

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

## Авторизованная проверка Matrix API

Для авторизованных запросов был использован тестовый Matrix-аккаунт:

```text
@daniil_api_test:kirill417163
```

Тестовая комната:

```text
API test Daniil
```

Внутренний ID комнаты:

```text
!xFgvWGzimsIkzuApJj:kirill417163
```

Access token не сохранялся в файлах проекта и передавался только через HTTP-заголовок:

```text
Authorization: Bearer <access_token>
```

## Проверка endpoints

### `/account/whoami`

Без токена сервер вернул ошибку авторизации:

```text
HTTP/1.1 401 Unauthorized
```

```json
{
  "errcode": "M_MISSING_TOKEN",
  "error": "Missing access token"
}
```

С токеном запрос был выполнен успешно:

```text
HTTP/1.1 200 OK
```

```json
{
  "user_id": "@daniil_api_test:kirill417163",
  "is_guest": false,
  "device_id": "MRBQAMPSIU"
}
```

Вывод: endpoint `/account/whoami` требует access token и с его помощью позволяет определить текущего пользователя.

### `/joined_rooms`

Без токена сервер вернул:

```text
HTTP/1.1 401 Unauthorized
```

С токеном сервер вернул список комнат пользователя:

```json
{
  "joined_rooms": [
    "!xFgvWGzimsIkzuApJj:kirill417163"
  ]
}
```

Вывод: список комнат пользователя доступен только после авторизации.

### `/publicRooms`

Без токена сервер вернул ошибку:

```text
HTTP/1.1 401 Unauthorized
```

С токеном запрос был выполнен успешно:

```text
HTTP/1.1 200 OK
```

```json
{
  "chunk": [],
  "total_room_count_estimate": 0
}
```

Вывод: публичный каталог комнат на данном сервере требует access token. При авторизованном запросе публичных комнат обнаружено не было.

### `/profile/{userId}`

Endpoint профиля оказался доступен как без токена, так и с токеном.

Без токена:

```text
HTTP/1.1 200 OK
```

С токеном:

```text
HTTP/1.1 200 OK
```

Ответ:

```json
{
  "displayname": "daniil_api_test"
}
```

Вывод: базовая информация профиля пользователя доступна без авторизации. Это отличается от endpoints, связанных с комнатами и пользовательской сессией.

### `/sync`

Без токена сервер вернул:

```text
HTTP/1.1 401 Unauthorized
```

С токеном:

```text
HTTP/1.1 200 OK
```

В ответе присутствуют данные синхронизации клиента: `next_batch`, список комнат, события, состояние комнаты и уведомления.

Вывод: endpoint `/sync` является авторизованным и возвращает состояние клиента только при наличии корректного access token.

### `/rooms/{roomId}/messages`

Без токена сервер вернул:

```text
HTTP/1.1 401 Unauthorized
```

С токеном:

```text
HTTP/1.1 200 OK
```

В ответе были получены события комнаты, включая отправленные тестовые сообщения.

Вывод: история сообщений комнаты доступна только авторизованному пользователю, который состоит в этой комнате.

### `/rooms/{roomId}/send/m.room.message/{txnId}`

Без токена сервер вернул ошибку авторизации:

```text
HTTP/1.1 401 Unauthorized
```

С токеном сообщение было успешно отправлено через Matrix API:

```text
HTTP/1.1 200 OK
```

```json
{
  "event_id": "$kSsXaWrXYDuDTfWNfQQVD3podkvpp5wHTaKnyBdmoHw"
}
```

Вывод: отправка сообщений через Matrix API возможна только при наличии корректного access token.

## Сводная таблица

| Endpoint                                                        | Метод | Без токена |    С токеном | Результат                                       |
| --------------------------------------------------------------- | ----- | ---------: | -----------: | ----------------------------------------------- |
| `/_matrix/client/versions`                                      | GET   |        200 | не требуется | Получен список поддерживаемых версий Matrix API |
| `/_matrix/client/v3/login`                                      | GET   |        200 | не требуется | Получен список доступных способов входа         |
| `/_matrix/client/v3/account/whoami`                             | GET   |        401 |          200 | С токеном возвращает текущего пользователя      |
| `/_matrix/client/v3/joined_rooms`                               | GET   |        401 |          200 | С токеном возвращает список комнат пользователя |
| `/_matrix/client/v3/publicRooms`                                | GET   |        401 |          200 | Каталог публичных комнат требует авторизации    |
| `/_matrix/client/v3/profile/{userId}`                           | GET   |        200 |          200 | Базовый профиль доступен без токена             |
| `/_matrix/client/v3/sync`                                       | GET   |        401 |          200 | С токеном возвращает состояние клиента          |
| `/_matrix/client/v3/rooms/{roomId}/messages`                    | GET   |        401 |          200 | С токеном возвращает историю сообщений комнаты  |
| `/_matrix/client/v3/rooms/{roomId}/send/m.room.message/{txnId}` | PUT   |        401 |          200 | С токеном позволяет отправить сообщение         |

## Итоговые выводы

В ходе API-исследования Matrix homeserver были проверены основные endpoints Matrix Client-Server API с access token и без него.

Базовые служебные endpoints `/_matrix/client/versions` и `/_matrix/client/v3/login` доступны без авторизации. Они позволяют определить поддерживаемые версии API и доступные способы входа.

Endpoints, связанные с пользовательской сессией, списком комнат, синхронизацией, чтением истории и отправкой сообщений, требуют корректный access token. При отсутствии токена сервер возвращает ошибку `M_MISSING_TOKEN`.

Endpoint `/profile/{userId}` оказался доступен без авторизации и возвращает базовую информацию профиля пользователя.

Таким образом, Matrix homeserver корректно ограничивает доступ к пользовательским данным и действиям через token-based authentication. Авторизованный пользователь может получать список своих комнат, синхронизировать состояние клиента, читать историю доступной комнаты и отправлять сообщения через Matrix Client-Server API.

