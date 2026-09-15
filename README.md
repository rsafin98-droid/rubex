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
