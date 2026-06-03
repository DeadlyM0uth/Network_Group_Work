# Групповая лабораторная работа. Сети и протоколы
## Команда анализа трафика
## Участники команды
| Участник | Задачи |
|---|---|
| Некрасов Богдан | XXX |
| Смирнов Вадим | XXX |
| Желанов Даниил | XXX |
| Хузин Рафаэль | XXX |
| Понкратов Николай | XXX |
| Эрцеговац Данила | XXX |
| Бадмаев Николай | XXX | 
## Контекст
Команда 1 предоставила мессенджер. Скорее всего, была взята серверная реализация Matrix homeserver, например, Synapse как самая распространённая. Получается, сервер/приложение поддерживает Matrix Client-Server API. Скорее всего, он развернут в Docker. Приложение присоединено к Tailscale сети. Таким образом сервер стал доступен в Tailscale сети для других участников сети.

Наша цель - провести исследование возможностей взаимодействия с мессенджером.
## Описание работы
### Общее исследование
В рамках данного блока было проведено исследование общей информации сервера. Цель данного блока - идентифицировать приложение, описать его и направить текущую работу.

- Админ/владелец сети tailscale добавил исследователей в сеть tailscale. В связи с бесплатной версией допустимо иметь три аккаунта в сети. Исследователи, завершив свою часть работы, освобождали место для другого исследователя.
- Установлен Tailscale, исследователи подключились к сети urgentb.github. Теперь возможно взаимодействие с сетью через командную строку
- Произведён `tailscale status` запрос. Получена информация о подключённых к Tailscale-сети устройствах:

```text
100.125.222.113  rulpw0j6tr1       danilaercegovac@  windows  -
100.115.145.26   desktop-9hrajbu   UrgentB@          windows  offline, last seen 21h ago
100.71.2.102     iphone-13         UrgentB@          iOS      offline, last seen 21h ago
100.64.219.105   macbook-pro       bogdan.nekpasrv@  macOS    -
100.83.165.96    messenger-server  pepe1az@          linux    -
100.100.79.15    s-macbook-air     UrgentB@          macOS    offline, last seen 21h ago
100.98.58.63     vadim             thedeadlymounth@  linux    offline, last seen 3h ago
```
Целевой сервер мессенджера идентифицирован как:
```text
100.83.165.96  messenger-server  pepe1az@  linux
```
Наличие устройства `messenger-server` в выводе `tailscale status` подтверждает, что сервер отображается в текущей Tailscale-сети и доступен исследователю на уровне сетевой видимости.

- Произведён `tailscale ip` запрос. Получены Tailscale-адреса текущего устройства исследователя:

```text
100.125.222.113
fd7a:115c:a1e0::3d39:de71
```

- Произведён `tailscale netcheck` запрос. Получена диагностическая информация о сетевом подключении Tailscale:

```text
UDP: true
IPv4: yes, 81.0.113.115:62604
IPv6: no, but OS has support
CaptivePortal: false
Nearest DERP: Frankfurt
```

По результатам проверки установлено, что UDP-доступность присутствует, IPv4-соединение активно, IPv6 на текущем подключении не используется, captive portal не обнаружен. Ближайший DERP-релей определён как Frankfurt.

Также получена информация о задержках до DERP-регионов. Минимальная задержка зафиксирована до Frankfurt — `73.5ms`, далее Nuremberg — `73.9ms`, Amsterdam — `76.4ms`, Paris — `81.2ms`.

- Произведён `tailscale status --json` запрос. Получена расширенная информация о текущем состоянии Tailscale-клиента, текущем устройстве, tailnet и доступных peer-устройствах.

В результате установлено:

```text
Version: 1.98.4
BackendState: Running
TUN: true
HaveNodeKey: true
CurrentTailnet: urgentb.github
MagicDNSSuffix: tail9da30d.ts.net
MagicDNSEnabled: true
```

Это подтверждает, что Tailscale-клиент запущен, устройство находится в tailnet `urgentb.github`, а MagicDNS включён. DNS-суффикс сети: `tail9da30d.ts.net`.

Целевой сервер мессенджера в списке peer-устройств:

```text
HostName: messenger-server
DNSName: messenger-server.tail9da30d.ts.net.
OS: linux
Tailscale IPv4: 100.83.165.96
Tailscale IPv6: fd7a:115c:a1e0::6639:a560
Online: true
Relay: hel
Created: 2026-05-29T18:14:53Z
KeyExpiry: 2026-11-25T20:21:32Z
```

На основании этих данных подтверждено, что `messenger-server` является отдельным Tailscale-узлом в сети `urgentb.github`, имеет MagicDNS-имя `messenger-server.tail9da30d.ts.net`, работает под управлением Linux и находится в состоянии online.

- Произведён `ping messenger-server` запрос. Выполнена проверка сетевой доступности узла `messenger-server` по имени внутри Tailscale/MagicDNS:

```text
Pinging messenger-server.tail9da30d.ts.net. [100.83.165.96] with 32 bytes of data:
Reply from 100.83.165.96: bytes=32 time=382ms TTL=64
Reply from 100.83.165.96: bytes=32 time=20ms TTL=64
Reply from 100.83.165.96: bytes=32 time=24ms TTL=64
Reply from 100.83.165.96: bytes=32 time=173ms TTL=64

Packets: Sent = 4, Received = 4, Lost = 0 (0% loss)
Minimum = 20ms, Maximum = 382ms, Average = 149ms
```

По результатам проверки установлено, что имя `messenger-server` успешно разрешается в DNS-имя `messenger-server.tail9da30d.ts.net` и Tailscale IP `100.83.165.96`. Потерь пакетов не зафиксировано, что подтверждает базовую сетевую доступность узла.

- Произведён `tailscale ping messenger-server` запрос. Выполнена проверка доступности узла средствами Tailscale:

```text
pong from messenger-server (100.83.165.96) via 176.12.68.83:41641 in 22ms
```

Ответ подтверждает, что узел `messenger-server` доступен внутри Tailscale-сети. Соединение выполнено с узлом `100.83.165.96`.

- Произведён `tailscale whois messenger-server` запрос. Получен ответ об ошибке:

```text
400 Bad Request: invalid 'addr' parameter
```

Данная ошибка указывает, что команда `tailscale whois` в текущем варианте ожидает IP-адрес, а не имя устройства. Для получения информации о целевом узле был выполнен повторный запрос с использованием Tailscale IP-адреса.

- Произведён `tailscale whois 100.83.165.96` запрос. Получена информация о целевом Tailscale-узле:

```text
Machine:
  Name:          messenger-server.tail9da30d.ts.net
  ID:            ne8dA5fApP11CNTRL
  Addresses:     [100.83.165.96/32 fd7a:115c:a1e0::6639:a560/128]
User:
  Name:     pepe1az@github
  ID:       4130514042221011
```

По результатам запроса подтверждено, что IP-адрес `100.83.165.96` принадлежит устройству `messenger-server.tail9da30d.ts.net`. Устройство имеет IPv4-адрес `100.83.165.96/32` и IPv6-адрес `fd7a:115c:a1e0::6639:a560/128`. Также установлен владелец устройства в Tailscale: `pepe1az@github`.

- Произведён `curl -I https://messenger-server` запрос. Выполнена попытка получить HTTP-заголовки по HTTPS на стандартном порту `443`:

```text
curl: (35) schannel: next InitializeSecurityContext failed: SEC_E_INTERNAL_ERROR (0x80090304) - The Local Security Authority cannot be contacted
```

Запрос завершился ошибкой TLS/Schannel на стороне Windows-клиента. Данный результат не подтверждает отсутствие сервиса, но указывает, что HTTPS-подключение к `https://messenger-server` на стандартном порту не было успешно установлено в текущей конфигурации клиента.

- Произведён `curl -I http://messenger-server` запрос. Выполнена проверка HTTP-сервиса на стандартном порту `80` по имени узла:

```text
HTTP/1.1 200 OK
Server: nginx
Date: Tue, 02 Jun 2026 14:35:00 GMT
Content-Type: text/html
Content-Length: 896
Last-Modified: Sat, 16 May 2026 18:07:20 GMT
Connection: keep-alive
ETag: "6a08b258-380"
Accept-Ranges: bytes
```

Получен ответ `HTTP/1.1 200 OK`, что подтверждает доступность HTTP-сервиса на узле `messenger-server`. В заголовке `Server` указано значение `nginx`, что позволяет идентифицировать используемый веб-сервер или reverse proxy.

- Произведён `curl -I http://100.83.165.96` запрос. Выполнена проверка HTTP-сервиса напрямую по Tailscale IP-адресу:

```text
HTTP/1.1 200 OK
Server: nginx
Date: Tue, 02 Jun 2026 14:36:14 GMT
Content-Type: text/html
Content-Length: 896
Last-Modified: Sat, 16 May 2026 18:07:20 GMT
Connection: keep-alive
ETag: "6a08b258-380"
Accept-Ranges: bytes
```

Ответ аналогичен запросу по имени `messenger-server`, что подтверждает доступность одного и того же HTTP-сервиса как по DNS-имени, так и по Tailscale IP `100.83.165.96`.

- Произведён `curl http://messenger-server:8008/_matrix/client/versions` запрос. Выполнена проверка Matrix Client-Server API endpoint `/versions` на порту `8008`:

```json
{
  "versions": [
    "r0.0.1",
    "r0.1.0",
    "r0.2.0",
    "r0.3.0",
    "r0.4.0",
    "r0.5.0",
    "r0.6.0",
    "r0.6.1",
    "v1.1",
    "v1.2",
    "v1.3",
    "v1.4",
    "v1.5",
    "v1.6",
    "v1.7",
    "v1.8",
    "v1.9",
    "v1.10",
    "v1.11",
    "v1.12"
  ],
  "unstable_features": {
    "org.matrix.label_based_filtering": true,
    "org.matrix.e2e_cross_signing": true,
    "org.matrix.msc2432": true,
    "uk.half-shot.msc2666.query_mutual_rooms.stable": true,
    "io.element.eee_forced.public": false
  }
}
```

По результатам запроса подтверждено наличие Matrix-compatible сервиса на порту `8008`. Endpoint возвращает список поддерживаемых версий Matrix Client-Server API, включая версии до `v1.12`. Это позволяет классифицировать сервис как Matrix homeserver либо совместимую с Matrix реализацию.

Также в ответе присутствует блок `unstable_features`, содержащий сведения о поддерживаемых экспериментальных или дополнительных возможностях Matrix API.

- Произведён `curl https://messenger-server:8448/_matrix/client/versions` запрос. Выполнена проверка доступности Matrix API по HTTPS на порту `8448`:

```text
curl: (7) Failed to connect to messenger-server port 8448 after 2175 ms: Could not connect to server
```

Соединение с портом `8448` установить не удалось. На основании результата можно сделать вывод, что на момент проверки сервис на порту `8448` недоступен с устройства исследователя. Это может означать, что порт закрыт, сервис на нём не запущен либо доступ ограничен сетевыми правилами.

- Произведён `nslookup messenger-server` запрос. Выполнена попытка разрешения короткого имени `messenger-server` через системный DNS-сервер:

```text
Server:  UnKnown
Address:  10.100.0.40

*** UnKnown can't find messenger-server: Non-existent domain
```

Системный DNS-сервер `10.100.0.40` не смог разрешить короткое имя `messenger-server`. При этом ранее команда `ping messenger-server` успешно разрешила имя в `messenger-server.tail9da30d.ts.net`. Это указывает, что разрешение имени может выполняться через механизмы Tailscale/MagicDNS или системный resolver, отличающийся от прямого запроса `nslookup`.

- Произведён `curl http://messenger-server:8008/_matrix/client/v3/login` запрос. Выполнена проверка доступных механизмов аутентификации Matrix Client-Server API:

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

Ответ указывает, что сервер поддерживает вход по паролю через `m.login.password`, а также механизм `m.login.application_service`. Наличие данного endpoint дополнительно подтверждает работу Matrix Client-Server API на порту `8008`.

- Произведён `curl http://messenger-server:8008/.well-known/matrix/client` запрос. Выполнена проверка Matrix client discovery:

```json
{
  "m.homeserver": {
    "base_url": "https://messenger-server.tail9da30d.ts.net/"
  }
}
```

Ответ содержит параметр `m.homeserver.base_url`, указывающий основной адрес homeserver для Matrix-клиентов:

```text
https://messenger-server.tail9da30d.ts.net/
```
Данный результат показывает, что для клиентских приложений Matrix опубликован base URL homeserver, использующий MagicDNS-домен Tailscale.

- Произведён `ping messenger-server.tail9da30d.ts.net` запрос. Выполнена проверка сетевой доступности узла по полному MagicDNS-имени:

```text
Pinging messenger-server.tail9da30d.ts.net. [100.83.165.96] with 32 bytes of data:
Reply from 100.83.165.96: bytes=32 time=21ms TTL=64
Reply from 100.83.165.96: bytes=32 time=19ms TTL=64
Reply from 100.83.165.96: bytes=32 time=21ms TTL=64
Reply from 100.83.165.96: bytes=32 time=19ms TTL=64

Packets: Sent = 4, Received = 4, Lost = 0 (0% loss)
Minimum = 19ms, Maximum = 21ms, Average = 20ms
```

По результатам проверки подтверждено, что полное MagicDNS-имя `messenger-server.tail9da30d.ts.net` разрешается в Tailscale IP `100.83.165.96`.

- Произведён `curl -I https://messenger-server.tail9da30d.ts.net/` запрос. Выполнена проверка HTTPS-сервиса по адресу, опубликованному в Matrix client discovery:

```text
HTTP/1.1 302 Found
Alt-Svc: h3=":443"; ma=2592000
Content-Length: 208
Content-Type: text/html; charset=utf-8
Date: Wed, 03 Jun 2026 07:53:37 GMT
Location: /_matrix/static
Server: Synapse/1.153.0
Via: 1.1 Caddy
```

Получен ответ `HTTP/1.1 302 Found`, указывающий на перенаправление к ресурсу `/_matrix/static`. В заголовке `Server` указано значение `Synapse/1.153.0`, что позволяет идентифицировать конкретную реализацию Matrix homeserver как **Synapse версии 1.153.0**. Также присутствует заголовок `Via: 1.1 Caddy`, что указывает на использование Caddy в качестве reverse proxy или промежуточного веб-сервера. 

- Произведён `curl https://messenger-server.tail9da30d.ts.net/_matrix/client/versions` запрос. Выполнена проверка Matrix Client-Server API через опубликованный HTTPS `base_url`:

```json
{
  "versions": [
    "r0.0.1",
    "r0.1.0",
    "r0.2.0",
    "r0.3.0",
    "r0.4.0",
    "r0.5.0",
    "r0.6.0",
    "r0.6.1",
    "v1.1",
    "v1.2",
    "v1.3",
    "v1.4",
    "v1.5",
    "v1.6",
    "v1.7",
    "v1.8",
    "v1.9",
    "v1.10",
    "v1.11",
    "v1.12"
  ]
}
```

Ответ подтверждает, что Matrix Client-Server API доступен не только через `http://messenger-server:8008`, но и через опубликованный HTTPS-адрес `https://messenger-server.tail9da30d.ts.net`. Сервер поддерживает версии Matrix Client-Server API до `v1.12`, а также возвращает список дополнительных `unstable_features`. 

- Произведён `curl http://messenger-server` запрос. Получено тело HTML-страницы, отдаваемой сервисом на порту `80`:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy,
API gateway, load balancer, content cache, or other features.</p>
...
</html>
```

Полученная страница является стандартной приветственной страницей nginx. Это указывает, что на HTTP-порту `80` запущен nginx, однако для данного виртуального хоста, вероятно, не настроено прикладное содержимое или корректное перенаправление на Matrix/веб-клиент. 

- Произведён `curl http://messenger-server:8008/_matrix/client/v3/register` запрос. Выполнена проверка endpoint регистрации Matrix Client-Server API:

```json
{
  "errcode": "M_UNRECOGNIZED",
  "error": "Unrecognized request"
}
```

Сервер вернул ошибку `M_UNRECOGNIZED`, что указывает на то, что указанный endpoint в данном виде не был распознан сервером на порту `8008`.

- Произведён `curl http://messenger-server:8008/_matrix/client/v3/publicRooms` запрос. Выполнена проверка доступности публичного каталога комнат Matrix:

```json
{
  "errcode": "M_MISSING_TOKEN",
  "error": "Missing access token"
}
```

Сервер вернул ошибку `M_MISSING_TOKEN`, что означает отсутствие access token в запросе. Это указывает, что доступ к публичному каталогу комнат через данный endpoint требует аутентификации.

- Произведён `curl -v http://messenger-server` запрос. Выполнена расширенная проверка HTTP-соединения с узлом `messenger-server`:

```text
* Host messenger-server:80 was resolved.
* IPv4: 100.83.165.96
* Trying 100.83.165.96:80...
* Established connection to messenger-server (100.83.165.96 port 80) from 100.125.222.113 port 57195
> GET / HTTP/1.1
> Host: messenger-server
> User-Agent: curl/8.19.0
> Accept: */*
< HTTP/1.1 200 OK
< Server: nginx
< Content-Type: text/html
< Content-Length: 896
```

Verbose-режим подтвердил, что имя `messenger-server` разрешается в IPv4-адрес `100.83.165.96`, после чего устанавливается HTTP-соединение с портом `80`. Ответ сервера содержит `HTTP/1.1 200 OK`, заголовок `Server: nginx` и HTML-страницу стандартной установки nginx. 

- Был создан аккаунт в мессенджер и произведён вход
  - Перешёл по https://app.element.io/
  - Нажал Создать аккаунт
  - Нажал Edit homeserver
  - Указал https://messenger-server.tail9da30d.ts.net/
  - Произошёл перенаправление на начальную страницу мессенджера
Получилось зайти именно в мессенджер (не дефолтный) команды 1. Это так, потому что аккаунт создался с Matrix ID - @danilaercegovac:kirill417163.

kirill417163 - server_name. При этом технический base_url homeserver опубликован как https://messenger-server.tail9da30d.ts.net/. Такое может быть

