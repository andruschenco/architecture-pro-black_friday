###### Примечание: Данный набор команд под Windows Poweshell, т.к. в этот раз использую Docker Desktop т.к. моя виртуалка с Ubuntu неожиданно померла.

## Задание 2. Шардирование MongoDB

---
## Структура решения

## Полный набор команд для PowerShell:

### 1. Инициализация Config Server
```powershell
docker compose exec -T config-srv mongosh --port 27017 --quiet --eval "rs.initiate({ _id: 'configReplSet', configsvr: true, members: [{ _id: 0, host: 'config-srv:27017' }] })"
```

### 2. Подождать 10 секунд
```powershell
Start-Sleep -Seconds 10
```

### 3. Инициализация Shard 1
```powershell
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "rs.initiate({ _id: 'shard1ReplSet', members: [{ _id: 0, host: 'shard1:27018' }] })"
```

### 4. Инициализация Shard 2
```powershell
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "rs.initiate({ _id: 'shard2ReplSet', members: [{ _id: 0, host: 'shard2:27019' }] })"
```

### 5. Подождать 15 секунд
```powershell
Start-Sleep -Seconds 15
```

### 6. Перезапустить mongos
```powershell
docker compose restart mongos
Start-Sleep -Seconds 10
```

### 7. Добавить шарды и настроить шардирование
```powershell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.addShard('shard1ReplSet/shard1:27018')"
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.addShard('shard2ReplSet/shard2:27019')"
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.enableSharding('somedb')"
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "sh.shardCollection('somedb.helloDoc', { '_id': 'hashed' })"
```

### 8. Заполнить данными (через Python в контейнере)
```powershell
docker compose exec -T pymongo_api python -c @"
from pymongo import MongoClient
client = MongoClient('mongodb://mongos:27017')
db = client['somedb']
collection = db['helloDoc']
for i in range(1500):
    collection.insert_one({'index': i, 'data': f'test_data_{i}'})
print('Inserted 1500 documents')
"@
```

### 9. Проверить результаты
```powershell
# Общее количество через mongos
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

# Количество в Shard 1
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

# Количество в Shard 2
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
```

###### Примечания:
###### Если используется версия **PowerShell 5.x или 7.x**, синтаксис с `@""@` должен работать. Если нет — используйте способ 2 (однострочные команды с `--eval`), он наиболее совместимый.
###### Команды типа "Start-Sleep -Seconds 10" при ручном последовательном исполнении носят исключительно информационный характер, естественно их выполнять не надо :)


### 10. Проверить приложение
#### Открыть в браузере по ссылке ниже (порт 8089 переопределен т.к. часто 8080 занят в самой ОС другими прогами)
```
http://localhost:8089/
```
#### Проверить логи
```powershell
PS E:\YaPracticumArc\architecture-pro-black_friday\mongo-sharding> docker compose logs pymongo_api
```
```powershell
pymongo_api  | {"asctime": "2026-04-04 18:24:26,441", "process": 1, "levelname": "INFO", "X-API-REQUEST-ID": "f7e82881-e19e-400a-ab83-8f1f78fccf3c", "request": {"method": "GET", "path": "/health", "ip": "172.18.0.1"}, "response": {"status": "failed", "status_code": 404, "time_taken": "0.0016s"}}
pymongo_api  | {"asctime": "2026-04-04 18:25:00,229", "process": 1, "levelname": "INFO", "X-API-REQUEST-ID": "b143a6e7-0cb7-4f22-8db1-16ef62f8bd31", "request": {"method": "GET", "path": "/", "ip": "172.18.0.1"}, "response": {"status": "successful", "status_code": 200, "time_taken": "22.0890s"}}
pymongo_api  | {"asctime": "2026-04-04 18:25:00,232", "process": 1, "levelname": "INFO", "X-API-REQUEST-ID": "c9e19b4d-5875-4504-bcbb-897aca5ab0b4", "request": {"method": "GET", "path": "/", "ip": "172.18.0.1"}, "response": {"status": "successful", "status_code": 200, "time_taken": "28.6647s"}}
pymongo_api  | {"asctime": "2026-04-04 18:29:03,821", "process": 1, "levelname": "INFO", "X-API-REQUEST-ID": "6bb6e966-7876-4bc8-af07-3899099c9a30", "request": {"method": "GET", "path": "/", "ip": "172.18.0.1"}, "response": {"status": "successful", "status_code": 200, "time_taken": "0.0129s"}}
PS E:\YaPracticumArc\architecture-pro-black_friday\mongo-sharding>
```

### 11. Подготовка к следующему заданию
##### Удаление всех созданных томов
```powershell
docker compose down -v
```