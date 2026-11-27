# Учёт компьютерной техники — «Компьюмаркет»

Проект производственной практики для магазина компьютерной техники «Компьюмаркет», г. Новоузенск. Настольное приложение C# / WPF с PostgreSQL и отчёт о выполненной работе.

## Состав

- `Prodahi_Ychet2/` — исходный код приложения (.NET Framework 4.7.2, Npgsql 8.0.9).
- `Prodahi_Ychet2.slnx` — решение Visual Studio.
- `practice/sql/` — создание схемы, начальные данные и проверки.
- `practice/scripts/` — резервное копирование и проверочное восстановление.
- `practice/report/Отчёт Компьюмаркет с иллюстрациями.docx` — итоговый отчёт на 20 страницах.
- `practice/figures/` — изображения интерфейса и диаграммы из отчёта.
- `practice/evidence/` — результаты проверок базы и восстановления.

## Возможности

Каталог товаров, поступление, продажа, контроль остатков, средневзвешенная закупочная стоимость, журнал движений в БД и расчёт валовой прибыли. Исходный учебный каталог: 8 категорий, 21 товар, 191 единица остатка. Он не является инвентаризацией реального магазина.

## Сборка

Нужны Windows, MSBuild с поддержкой WPF (Visual Studio) и доступ к NuGet. В Developer PowerShell выполните:

```powershell
msbuild Prodahi_Ychet2/Prodahi_Ychet2.csproj /restore /t:Build /p:Configuration=Release
```

Результат: `Prodahi_Ychet2/bin/Release/Prodahi_Ychet2.exe`. Сборки .NET Framework 4.7.2 восстанавливаются через NuGet; на компьютере для запуска должна быть установлена совместимая версия .NET Framework.

## PostgreSQL

Проверено с PostgreSQL 17.5. Команды выполняются из каталога репозитория; утилиты PostgreSQL должны быть доступны в PATH. Создавайте новую отдельную базу — скрипты не предназначены для существующей рабочей схемы.

```powershell
createdb -h localhost -U postgres prodahi_practice
psql -h localhost -U postgres -d prodahi_practice -v ON_ERROR_STOP=1 -f practice/sql/01_schema.sql
psql -h localhost -U postgres -d prodahi_practice -v ON_ERROR_STOP=1 -f practice/sql/02_seed.sql
psql -h localhost -U postgres -d prodahi_practice
```

В интерактивной сессии psql настройте учётную запись приложения (пароль вводится через запрос, в репозитории его нет):

```sql
CREATE ROLE prodahi_app LOGIN;
\password prodahi_app
GRANT prodahi_operator TO prodahi_app;
REVOKE CONNECT ON DATABASE prodahi_practice FROM PUBLIC;
GRANT CONNECT ON DATABASE prodahi_practice TO prodahi_operator, prodahi_reader;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
\q
```

Создайте `%LOCALAPPDATA%\Prodahi_Ychet2\connection.txt` с собственной строкой подключения:

```text
Host=localhost;Port=5432;Database=prodahi_practice;Username=prodahi_app;Password=<ваш пароль>;Timeout=5;Command Timeout=15;SSL Mode=Disable
```

Это настройка локального учебного стенда. Для сетевого подключения настройте TLS с проверкой сертификата и ограничение доступа. Файл содержит пароль в открытом виде: храните его только в своём профиле, не добавляйте в Git. Учётная запись приложения получает доступ через роль оператора, а не права суперпользователя.

## Проверка и резервные копии

```powershell
psql -h localhost -U postgres -d prodahi_practice -f practice/sql/03_verify.sql
./practice/scripts/Backup-Database.ps1
./practice/scripts/Restore-Database.ps1 -BackupPath '<путь к файлу .dump>'
```

Проверки выполняются с откатом тестовых изменений. Сценарий восстановления создаёт отдельную новую базу `prodahi_restore_*`, не перезаписывая рабочую. Переносимая копия не содержит назначений владельцев и прав: для последующей эксплуатации их нужно настроить отдельно. Планировщик резервного копирования автоматически не устанавливается.

## Отчёт

AD DS и AD CS рассмотрены теоретически; виртуальная машина и доменная инфраструктура не развёртывались. Изображения интерфейса получены средствами WPF из работающего приложения с данными PostgreSQL. SQL-проверки и пробное восстановление выполнены фактически.
