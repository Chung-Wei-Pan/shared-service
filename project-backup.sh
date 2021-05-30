#!/bin/sh

# 此為本主機專案備份檔案，執行一次備份一個專案
# NAME 以備份日期命名備份檔
# BACKUP_DIR 要備份的資料夾
# SOURCE_DIR 專案來源資料夾
# DB 資料庫名稱
# DB_USER 資料庫使用者
# DB_PASSWORD 資料庫密碼

NAME=$(date +%Y-%m-%d)
BACKUP_DIR=$1
SOURCE_DIR=$2
DB=$3
DB_USER=
DB_PASSWORD=
# 備份後將檔案放上 FTP，因此需要設定相關資訊
FTP_SERVER=
FTP_DIR=
FTP_USER=
FTP_PASSWORD=
echo "Project Path $SOURCE_DIR"
echo "Backup date: ${NAME}"
# 若沒有備份路徑，則建立備份資料夾
if [ ! -d "$BACKUP_DIR" ]; then
    echo "$BACKUP_DIR is not exists."
    echo "Create new director: $BACKUP_DIR"
    mkdir -p $BACKUP_DIR
fi
echo
if [ -f "${BACKUP_DIR}/${NAME}.tgz" ]; then
    echo "Backup file ${NAME}.tgz exists."
else 
    # 將 $SOURCE_DIR 備份至 ${BACKUP_DIR}
    date
    echo "Start to backup $SOURCE_DIR..."
    # -C 要備份資料的父資料夾
    # --exclude 避免備份的資料夾 (node_modules, vendor 是可以透過 npm composer 重新產生的資料，mysql 則是建立 docker 資料庫的對應檔案)
    if [[ -n "$IS_LARAVEL" ]]; then vendor_arg="--exclude vendor"; fi
    tar -C /home/docker/ -zcvf ${BACKUP_DIR}/${NAME}.tgz --exclude "node_modules" $vendor_arg --exclude ".svn" --exclude ".git" --exclude "mysql" $SOURCE_DIR
    # 將備份檔案透過 sftp 方式備份至 NAS
    date
    echo "Backup $SOURCE_DIR is finished !"
fi
echo
if ! [ -z "$DB" ]; then
    if [ -f  "${BACKUP_DIR}/${NAME}.sql" ]; then
        echo "Backup file ${NAME}.sql exists."
    else
        # 由於本主機專案共用資料庫，因此須透過 docker 備份資料
        # 共用資料庫所在的資料夾
        cd /home/docker/shared-service
        echo "---- Shared Service Directory Path ----"
        pwd
        echo "---------------------------------------"
        echo "Start to backup Database: $DB..."
        docker-compose exec -T mysql bash -c "export MYSQL_PWD=$DB_PASSWORD"
        docker-compose exec -T mysql mysqldump -u$DB_USER -p$DB_PASSWORD $DB > $BACKUP_DIR/$NAME.sql
    fi
else
    echo "This is shared service."
fi
echo
# 將備份檔案放至 FTP
echo "ftp server path: $FTP_DIR/"
expect << EOS
spawn sftp ${FTP_USER}@${FTP_SERVER}:${FTP_DIR}
expect "Password:"
send "${FTP_PASSWORD}\n"
expect "sftp>"
send "put ${BACKUP_DIR}/${NAME}.*\n"
expect "sftp>"
send "bye\n"
EOS
# 刪除超過 3 天的專案、資料庫
find ${BACKUP_DIR}/*.tgz -mtime +2 -exec rm {} \;
find ${BACKUP_DIR}/*.sql -mtime +2 -exec rm {} \;
