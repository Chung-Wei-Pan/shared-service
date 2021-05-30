#!/bin/bash

# 將資料庫重置的腳本
DB_NAME=$1
DB_BACKUP_PATH=$2
DB_PASSWD=$3
​
echo "DB_NAME：$DB_NAME"
echo "DB_BACKUP_PATH：$DB_BACKUP_PATH"
echo "DROP database...$DB_NAME Start"
docker-compose exec -T mysql mysql -u root -p$DB_PASSWD -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
echo "DROP database...$DB_NAME End"
​
echo "CREATE database...$DB_NAME Start"
docker-compose exec -T mysql mysql -u root -p$DB_PASSWD -e "CREATE DATABASE \`$DB_NAME\` character set UTF8 collate utf8_unicode_ci;"
echo "CREATE database...$DB_NAME End"
​
​
echo "rollback database...$DB_NAME Start"
docker-compose exec -T mysql mysql -u root -p$DB_PASSWD -D $DB_NAME < $DB_BACKUP_PATH
echo "rollback database...$DB_NAME End"

