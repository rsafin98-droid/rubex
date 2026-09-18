# RUBEX — персональная криптобиржа (Next.js + PostgreSQL)

Личный спот-терминал в рублях: живые котировки, лимитные и маркет-ордера, кошелёк с балансом
**550 000 ₽**, депозиты и выводы, история сделок, настройки профиля.

Демо-доступ: `owner@rubex.trade` / `rubex2026`

---

## 1. Что нужно

| Компонент | Версия | Зачем |
|---|---|---|
| **Docker Desktop** (самый простой вариант) | последняя | запускает всё одной командой |
| Node.js (для запуска без Docker) | 20 LTS или новее | запуск приложения |
| PostgreSQL (для запуска без Docker) | 14+ (рекомендуется 16) | хранение данных |
| Браузер | Safari 16+, Chrome, Edge | интерфейс, PWA |

---

## 2. Docker — самый простой способ (одна команда)

Установите Docker Desktop для Windows (нужны WSL2 и виртуализация в BIOS), затем в папке проекта:

```powershell
docker compose up -d --build
```

> **Слабый ноутбук (8 ГБ RAM, 2 ядра) — пропусти этот раздел.** Docker Desktop поднимает
> WSL2-виртуалку и забирает 1,5–2 ГБ памяти: на 6 ГБ доступной RAM это означает постоянный
> своп и «тормозит весь ноутбук». Иди сразу в раздел 3 и ставь PostgreSQL службой.

Готово — PostgreSQL (порт 5432) и приложение (порт 3000) поднимутся сами, таблицы и демо-данные
(баланс 550 000 ₽) создадутся автоматически.

- Открыть: `http://localhost:3000` (с телефона в той же сети — `http://IP_ПК:3000`).
- Логи: `docker compose logs -f app`.
- Остановить (данные сохранятся): `docker compose down`.
- Полный сброс вместе с базой: `docker compose down -v`.

Пароли меняются в `docker-compose.yml`: `POSTGRES_PASSWORD`, `DATABASE_URL`, `AUTH_SECRET`.

---

> **Сборка падает с ошибкой «Не удалось найти каталог pages или app»?** Это значит, что в корне
> репозитория нет папки `src`. Проверьте, что `package.json` и `src/` лежат в корне (не внутри вложенной
> папки). Либо в Vercel → Settings → Git → **Root Directory** укажите вложенную папку. Чистый ZIP проекта
> можно скачать на странице `/install` работающего приложения (файл `/rubex-project.zip`).

---

## 3. Windows — локальный запуск (без Docker)

```powershell
# 1. создать базу (один раз)
& "C:\Program Files\PostgreSQL\16\bin\createdb.exe" -U postgres app_db

# 2. создать файл .env в корне проекта
#    DATABASE_URL=postgresql://postgres:ВАШ_ПАРОЛЬ@127.0.0.1:5432/app_db
#    AUTH_SECRET=любая_длинная_случайная_строка

# 3. зависимости + таблицы
npm install
npx drizzle-kit push

# 4. сборка и старт
npm run build
npm start
```

Откройте <http://localhost:3000>. При первом обращении база автоматически создаётся
и наполняется демо-данными (13 рынков, история цен, ордера, сделки, баланс 550 000 ₽).

Остановить сервер — `Ctrl + C`. Занят порт 3000 — `npm start -- -p 3001`.

### Открыть с телефона в той же Wi-Fi сети

```powershell
npm start -- -H 0.0.0.0 -p 3000
ipconfig                          # узнать IPv4, например 192.168.1.50
netsh advfirewall firewall add rule name="RUBEX" dir=in action=allow protocol=TCP localport=3000
```

На iPhone откройте `http://192.168.1.50:3000`.

---

### 3.1. Если ноутбук слабый (≤8 ГБ RAM / 2 ядра) — экономим память

Проверь, сколько реально доступно: `Win+R` → `msinfo32` → «Всего физической памяти» против
«Доступно физической памяти». На ноутбуках с встроенной графикой Radeon/Vega 2 ГБ из 8 отъедается
под iGPU — остаётся ~6 ГБ, и их легко съесть одному браузеру.

**Не запускай Docker Desktop «просто для базы».** Нативный PostgreSQL-сервис Windows в простое
занимает порядка 50–100 МБ, WSL2-виртуалка — гигабайты.

```powershell
# один раз: ставишь PostgreSQL 16 (установщик EDB, только «Server»), затем:
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "create database app_db;"

# каждый запуск: лимит heap'а Node, чтобы dev-сервер не упёрся в своп
$env:NODE_OPTIONS = '--max-old-space-size=1536'
$env:NEXT_TELEMETRY_DISABLED = '1'
npm run dev
```

Ещё три вещи, которые на такой машине дают заметный эффект:

1. **Исключение папки проекта в Defender** (запустить от админа) — иначе антивирус сканирует
   каждый файл внутри `node_modules` при установке и сборке:
   ```powershell
   Add-MpPreference -ExclusionPath "C:\путь\к\rubex"
   ```
2. **Отключить автозапуск Docker Desktop / WSL**, если ими не пользуешься каждый день.
3. **Не держать `npm run build` и `npm run dev` одновременно** — на 4 потоках они делят CPU
   и оба падают в 2–3 раза.

Диагностика и безопасная чистка — раздел 8.

---

## 4. iPhone / iPad / Android — установка иконки

1. Откройте адрес приложения в **Safari** (на Android — Chrome).
2. Войдите в аккаунт.
3. iPhone: кнопка **«Поделиться» → «На экран “Домой”»**.
   Android: меню ⋮ → **«Установить приложение»**.
4. Иконка RUBEX появится на экране, запуск — в полноэкранном режиме без адресной строки.

Это PWA: манифест и иконки лежат в `public/`.

### Windows — установить как приложение

Chrome: меню ⋮ → *Сохранить и поделиться → Установить страницу как приложение*.
Edge: меню ⋯ → *Приложения → Установить этот сайт как приложение*.

---

## 5. Хостинг в интернете (общий доступ с телефона и ПК)

### Рекомендуемый путь: Vercel + Neon (бесплатно)

1. **GitHub:** загрузите проект в репозиторий:
   ```bash
   git init && git add . && git commit -m "rubex exchange"
   git remote add origin git@github.com:ВАШ_ЛОГИН/rubex.git
   git push -u origin main
   ```
2. **Neon (база данных):** neon.tech → бесплатный проект → база `app_db` → скопируйте
   строку подключения (кнопка **Pooled**).
3. **Vercel:** vercel.com → Add New → Project → выберите `rubex` (Next.js определится сам) →
   в Environment Variables добавьте:
   ```
   DATABASE_URL=<строка из шага 2>
   AUTH_SECRET=<длинная случайная строка, от 16 символов>
   ```
   Нажмите Deploy.
4. Получите постоянную ссылку `https://rubex.vercel.app`. Таблицы и демо-данные
   (баланс 550 000 ₽) создаются автоматически при первом запросе — миграции вручную не нужны.
5. На iPhone: открыть в Safari → «Поделиться» → «На экран “Домой”».

Альтернативы: Railway (база и приложение в одном месте), VPS с `docker compose up -d --build`
и собственным доменом.

---

## 6. Полезные команды

```bash
# вернуть 550 000 ₽ на рублёвый спот-счёт
psql "$DATABASE_URL" -c "update balances set available='550000', locked='0' where symbol='RUB';"

# бэкап и восстановление
pg_dump app_db > rubex-backup.sql
psql app_db < rubex-backup.sql

# проверка состояния
curl http://localhost:3000/api/health
```

---

## 7. Структура

```
src/app/(app)/          защищённые страницы (дашборд, рынки, торговля, кошелёк, ордера, операции, настройки)
src/app/api/            REST-роуты: auth, markets, orders, transactions, wallet, watchlist, user, health
src/lib/bootstrap.ts    авто-создание таблиц + демо-данные
src/lib/market.ts       движок котировок (случайное блуждание) и матчинг ордеров
src/lib/exchange.ts     ордера, сделки, кошелёк, портфель, депозиты/выводы
src/db/schema.ts        схема Drizzle: users, assets, balances, orders, trades, transactions, watchlist, price_history
```

Комиссия сделок — 0.10%. Пароли хранятся как scrypt-хэши, сессия — подписанная httpOnly cookie.


---

## 8. Диагностика и безопасная чистка ноутбука (Windows)

В репозитории лежат два PowerShell-скрипта. Оба **только читают** и ничего сами не удаляют:

```powershell
# 1) снимок системы: RAM/планки/слоты, CPU, диски, автозапуск, Docker/WSL, сеть, ошибки
powershell -ExecutionPolicy Bypass -File .\tools\diag-windows.ps1
#    подробно (обход папок профиля, 2-10 мин): ... diag-windows.ps1 -Deep
#    результат: rubex-diag-<дата>.txt

# 2) что можно освободить (СУХОЙ ПРОГОН, удалять не будет)
powershell -ExecutionPolicy Bypass -File .\tools\cleanup-windows.ps1
#    реально почистить кэши: ... cleanup-windows.ps1 -Apply
#    плюс кэши сборки проектов: ... cleanup-windows.ps1 -Apply -PmCache -NodeModules C:\путь\к\rubex
#    системное (только из PowerShell от админа): ... cleanup-windows.ps1 -Apply -DeepSystem
#    результат: rubex-cleanup.txt
```

Типичные находки на 8-гигабайтных ноутбуках, которые дают реальный прирост:

| Что | Чем лечится |
|---|---|
| Свободно < 1 ГБ RAM, commit близок к лимиту | автозапуск, вкладки браузера, Docker/WSL; второй SODIMM на 8 ГБ |
| `pagefile` трещит, диск 73% занят | `-Apply` (Temp, кэши npm/pnpm/pip, браузеры, WER), `powercfg /h off` |
| `.vhdx` Docker Desktop на 20–40 ГБ | `docker system prune`, затем `diskpart → compact vdisk` (файл сам не сжимается) |
| Сборка/установка медленная | исключение папки проекта в Defender, `npm ci` вместо `npm install` |
| Ноутбук греется и сбрасывает частоты | BIOS/микрокод от 2021 года → обновить у HP, продуть вентилятор |
