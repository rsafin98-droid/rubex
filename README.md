# БИРЖА — личный крипто-терминал

Персональное веб-приложение в стиле криптобиржи: портфель, рынки, рыночные и лимитные ордера, история операций, пополнение/вывод и избранные монеты.

Приложение рассчитано на личное использование и запускается как сайт. Его можно добавить на экран iPhone или установить как приложение в Chrome/Edge на Windows.

## Демо-доступ

После первого запуска автоматически создаётся демо-аккаунт:

- логин: `me`
- пароль: `birzha`
- стартовый баланс: `550000 ₽`

При первом обращении к приложению автоматически заполняются монеты, демо-портфель, ордера, история и watchlist.

---

## Самый простой постоянный запуск: Neon + Vercel

### 1. Создать PostgreSQL в Neon

1. Откройте [neon.tech](https://neon.tech) и создайте аккаунт.
2. Создайте новый проект PostgreSQL.
3. В разделе **Connect** скопируйте строку подключения. Она выглядит примерно так:

```text
postgresql://user:password@ep-example.eu-central-1.aws.neon.tech/neondb?sslmode=require
```

Не публикуйте эту строку в GitHub или сообщениях — это пароль к базе данных.

### 2. Загрузить код на GitHub

В папке проекта выполните:

```bash
git init
git add .
git commit -m "Initial personal exchange"
git branch -M main
git remote add origin https://github.com/YOUR-LOGIN/YOUR-REPOSITORY.git
git push -u origin main
```

Если Git ещё не установлен на Windows, скачайте его с [git-scm.com](https://git-scm.com/download/win).

### 3. Создать проект в Vercel

1. Откройте [vercel.com](https://vercel.com) и войдите через GitHub.
2. Нажмите **Add New → Project**.
3. Выберите репозиторий.
4. В разделе **Environment Variables** добавьте:

```text
DATABASE_URL=ваша_строка_подключения_Neon
SESSION_SECRET=длинная_случайная_строка
```

Для `SESSION_SECRET` можно сгенерировать значение локально:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

5. Нажмите **Deploy**.

Vercel выдаст постоянный адрес вида:

```text
https://название-проекта.vercel.app
```

### Если Vercel пишет «Не удалось найти каталог pages или app»

Эта ошибка почти всегда означает, что Vercel собирает не корень проекта.

В Vercel откройте:

```text
Project → Settings → General → Root Directory
```

Укажите корневую папку проекта — именно ту, внутри которой одновременно находятся:

```text
package.json
src
public
next.config.ts
```

Обычно значение должно быть `.` или оставьте поле пустым. Не выбирайте `src` и не выбирайте папку уровнем выше, содержащую весь проект.

Если проект загружен архивом, проверьте структуру GitHub. Неправильно:

```text
repository/project-folder/package.json
```

Правильно:

```text
repository/package.json
repository/src/app/page.tsx
```

После исправления нажмите в Vercel:

```text
Deployments → Redeploy → Redeploy
```

В репозитории уже добавлен `vercel.json`, который явно указывает Vercel использовать Next.js и команду `npm run build`.

## 4. Один раз применить схему базы

Перед первым входом примените таблицы к базе Neon с компьютера.

**PowerShell в Windows:**

```powershell
$env:DATABASE_URL="postgresql://user:password@host/database?sslmode=require"
npx drizzle-kit push
```

**macOS/Linux:**

```bash
DATABASE_URL="postgresql://user:password@host/database?sslmode=require" npx drizzle-kit push
```

После этого откройте адрес Vercel. При первом запросе приложение само создаст демо-монеты и аккаунт.

> Если вы меняете схему базы в будущем, снова выполните `npx drizzle-kit push` с тем же `DATABASE_URL`.

---

## Локальный запуск на Windows

### Требования

- Node.js 20.9 или новее: [nodejs.org](https://nodejs.org)
- PostgreSQL 14 или новее: [postgresql.org](https://www.postgresql.org/download/windows/)

### Команды

Откройте PowerShell в папке проекта:

```powershell
npm install
Copy-Item .env.example .env
```

Откройте `.env` и укажите данные своей базы:

```env
DATABASE_URL=postgresql://postgres:ВАШ_ПАРОЛЬ@127.0.0.1:5432/app_db
SESSION_SECRET=любая-длинная-случайная-строка
```

Создайте базу `app_db`, если её ещё нет, затем выполните:

```powershell
npx drizzle-kit push
npm run dev
```

Откройте в браузере:

```text
http://localhost:3000
```

Для production-режима:

```powershell
npm run build
npm run start
```

---

## Установка на iPhone

После деплоя на Vercel:

1. Откройте постоянный адрес проекта в Safari.
2. Нажмите кнопку **Поделиться**.
3. Выберите **На экран «Домой»**.
4. Нажмите **Добавить**.

Приложение откроется отдельным окном с иконкой «БИРЖА».

## Установка на Windows как приложение

В Chrome:

1. Откройте адрес Vercel.
2. Нажмите значок установки справа в адресной строке или откройте `⋮ → Сохранить и поделиться → Установить страницу как приложение`.
3. Подтвердите установку.

В Microsoft Edge:

1. Откройте адрес Vercel.
2. Откройте `⋯ → Приложения → Установить этот сайт как приложение`.
3. При необходимости включите ярлык на рабочем столе.

---

## Проверка перед публикацией

```bash
npx next typegen
npm exec tsc -- --noEmit --pretty false
npm run build
```

Проверка базы и API:

```bash
curl http://localhost:3000/api/health
```

Ожидаемый ответ:

```json
{"ok":true}
```

---

## Важная безопасность

- Не коммитьте `.env`, `.env.local` и строку `DATABASE_URL` в GitHub.
- Используйте длинный уникальный `SESSION_SECRET`.
- Это личный демонстрационный терминал, а не настоящая биржа: цены симулируются в интерфейсе, реальные деньги и блокчейн-транзакции не подключены.
- Если приложение нужно закрыть только для себя, не публикуйте ссылку и используйте сложный пароль аккаунта.
