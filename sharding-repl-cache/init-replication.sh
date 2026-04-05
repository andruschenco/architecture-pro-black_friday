#!/bin/bash

echo "=== Initializing Replication for Sharded MongoDB Cluster ==="

# 1. Initialize Config Server Replica Set
echo "1. Initializing Config Server Replica Set..."
docker compose exec -T config-srv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "config-srv1:27017" },
    { _id: 1, host: "config-srv2:27017" },
    { _id: 2, host: "config-srv3:27017" }
  ]
})
EOF

# 2. Initialize Shard 1 Replica Set
echo "2. Initializing Shard 1 Replica Set..."
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF

# 3. Initialize Shard 2 Replica Set
echo "3. Initializing Shard 2 Replica Set..."
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]
})
EOF

# 4. Wait for Replica Sets to initialize
echo "4. Waiting for Replica Sets to initialize (20 seconds)..."
sleep 20

# 5. Add shards to the cluster
echo "5. Adding shards to the cluster..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2ReplSet/shard2-1:27019,shard2-2:27019,shard2-3:27019")
EOF

# 6. Enable sharding for database and collection
echo "6. Enabling sharding for database and collection..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "_id": "hashed" })
EOF

# 7. Insert test data into helloDoc (for sharding verification)
echo "7. Inserting test data into helloDoc (1500 documents)..."
docker compose exec -T pymongo_api python <<EOF
from pymongo import MongoClient
import time
client = MongoClient('mongodb://mongos:27017')
db = client['somedb']
collection = db['helloDoc']
# Clear existing data
collection.delete_many({})
for i in range(1500):
    collection.insert_one({'index': i, 'data': f'test_data_{i}', 'timestamp': time.time()})
print('✓ Inserted 1500 documents into helloDoc')
EOF

# 7.5. Create users for the application (users collection)
echo "7.5. Creating test users for the application..."
docker compose exec -T pymongo_api python <<EOF
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
print(f'✓ Created {len(result.inserted_ids)} users in users collection')
EOF

# 8. Check replication status
echo ""
echo "=== Replication Status Check ==="

echo "Shard 1 Replica Set Status:"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr)
})
EOF

echo "Shard 2 Replica Set Status:"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr)
})
EOF

echo "Config Server Replica Set Status:"
docker compose exec -T config-srv1 mongosh --port 27017 --quiet <<EOF
rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr)
})
EOF

# 9. Check document counts
echo ""
echo "=== Document Count Check ==="

echo "Total documents in helloDoc (via mongos):"
docker compose exec -T mongos mongosh --port 27017 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo "Documents in Shard 1 (PRIMARY):"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo "Documents in Shard 1 (SECONDARY - shard1-2):"
docker compose exec -T shard1-2 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo "Documents in Shard 2 (PRIMARY):"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo "Documents in Shard 2 (SECONDARY - shard2-2):"
docker compose exec -T shard2-2 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"


echo ""
echo "=== Replication Initialization Complete ==="