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

Текущее устройство исследователя:

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

Также в JSON-выводе присутствует информация о пользователях tailnet и связанных с ними устройствах. Это позволяет установить соответствие между устройствами, их владельцами, операционными системами, Tailscale IP-адресами, DNS-именами и статусом online/offline.

- 
- Был создан аккаунт в мессенджер и произведён вход
  - Перешёл по https://app.element.io/
  - Нажал Создать аккаунт
  - Нажал Edit homeserver
  - Указал https://messenger-server.tail9da30d.ts.net/
  - Произошёл перенаправление на начальную страницу мессенджера
Получилось зайти именно в мессенджер (не дефолтный) команды 1. Это так, потому что аккаунт создался с Matrix ID - @danilaercegovac:kirill417163.

kirill417163 - server_name. При этом технический base_url homeserver опубликован как https://messenger-server.tail9da30d.ts.net/. Такое может быть

