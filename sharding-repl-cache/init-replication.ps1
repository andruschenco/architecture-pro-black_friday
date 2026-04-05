# init-replication.ps1

Write-Host "=== Initializing Replication for Sharded MongoDB Cluster ===" -ForegroundColor Cyan

# 1. Initialize Config Server Replica Set
Write-Host "`n1. Initializing Config Server Replica Set..." -ForegroundColor Yellow
@"
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "config-srv1:27017" },
    { _id: 1, host: "config-srv2:27017" },
    { _id: 2, host: "config-srv3:27017" }
  ]
})
"@ | docker compose exec -T config-srv1 mongosh --port 27017 --quiet

# 2. Initialize Shard 1 Replica Set
Write-Host "2. Initializing Shard 1 Replica Set..." -ForegroundColor Yellow
@"
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
"@ | docker compose exec -T shard1-1 mongosh --port 27018 --quiet

# 3. Initialize Shard 2 Replica Set
Write-Host "3. Initializing Shard 2 Replica Set..." -ForegroundColor Yellow
@"
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]
})
"@ | docker compose exec -T shard2-1 mongosh --port 27019 --quiet

# Wait for all Replica Sets to initialize
Write-Host "`n4. Waiting for Replica Sets to initialize (20 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# 5. Add shards to the cluster
Write-Host "5. Adding shards to the cluster..." -ForegroundColor Yellow
@"
sh.addShard("shard1ReplSet/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2ReplSet/shard2-1:27019,shard2-2:27019,shard2-3:27019")
"@ | docker compose exec -T mongos mongosh --port 27017 --quiet

# 6. Enable sharding for database and collection
Write-Host "6. Enabling sharding for database and collection..." -ForegroundColor Yellow
@"
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "_id": "hashed" })
"@ | docker compose exec -T mongos mongosh --port 27017 --quiet

# 7. Insert test data
Write-Host "7. Inserting test data (1500 documents)..." -ForegroundColor Yellow
$pythonScript = @"
from pymongo import MongoClient
import time
client = MongoClient('mongodb://mongos:27017')
db = client['somedb']
collection = db['helloDoc']
for i in range(1500):
    collection.insert_one({'index': i, 'data': f'test_data_{i}', 'timestamp': time.time()})
print('✓ Inserted 1500 documents')
"@
$pythonScript | docker compose exec -T pymongo_api python -c "import sys; exec(sys.stdin.read())"


# 7.1. Create users for the application (users collection)
Write-Host "`n7.5. Creating test users for the application..." -ForegroundColor Yellow
$createUsersScript = @"
from pymongo import MongoClient
client = MongoClient('mongodb://mongos:27017')
db = client['somedb']

# Clear existing users
db.users.delete_many({})

# Create users
users_data = [
    {'name': 'Alice', 'age': 25},
    {'name': 'Bob', 'age': 30},
    {'name': 'Charlie', 'age': 35},
    {'name': 'Diana', 'age': 28},
    {'name': 'Eve', 'age': 22}
]

result = db.users.insert_many(users_data)
print(f'Created {len(result.inserted_ids)} users in users collection')
"@
$createUsersScript | docker compose exec -T pymongo_api python -c "import sys; exec(sys.stdin.read())"


# 8. Check replication status
Write-Host "`n=== Replication Status Check ===" -ForegroundColor Cyan

Write-Host "`nShard 1 Replica Set Status:" -ForegroundColor Yellow
@"
rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr)
})
"@ | docker compose exec -T shard1-1 mongosh --port 27018 --quiet

Write-Host "`nShard 2 Replica Set Status:" -ForegroundColor Yellow
@"
rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr)
})
"@ | docker compose exec -T shard2-1 mongosh --port 27019 --quiet

Write-Host "`nConfig Server Replica Set Status:" -ForegroundColor Yellow
@"
rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr)
})
"@ | docker compose exec -T config-srv1 mongosh --port 27017 --quiet

# 9. Check document counts
Write-Host "`n=== Document Count Check ===" -ForegroundColor Cyan

Write-Host "`nTotal documents (via mongos):" -ForegroundColor Yellow
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

Write-Host "`nDocuments in Shard 1 (PRIMARY):" -ForegroundColor Yellow
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

Write-Host "`nDocuments in Shard 1 (SECONDARY - shard1-2):" -ForegroundColor Yellow
docker compose exec -T shard1-2 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

Write-Host "`nDocuments in Shard 2 (PRIMARY):" -ForegroundColor Yellow
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

Write-Host "`nDocuments in Shard 2 (SECONDARY - shard2-2):" -ForegroundColor Yellow
docker compose exec -T shard2-2 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

Write-Host "`n=== Replication Initialization Complete ===" -ForegroundColor Green