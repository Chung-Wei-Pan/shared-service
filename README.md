# 主機共用服務

## 說明

此專案用於主機內的共用服務，使用 Docker 建置資料庫、反向代理、HTTPS 認證等服務

## 啟用及關閉
- 啟用服務
  - docker-compose up -d
- 關閉專案環境、container
  - docker-compose down

## 反向代理設定說明

### 如何新增反向代理
- 先將服務以及對應的 port 設置好
- 至 `./config/nginx/conf.d` 內建立一個新的設定檔
- nginx 設定檔範例如下
```conf
upstream example {
    # 反向代理到服務所開的 port
    server 172.17.0.1:8081;
}

server {
    listen 80;
    server_name ${指到主機的網域};
    
    location / {
        return 301 https://$host$request_uri;
    }   

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

}

server {
    listen 443 ssl;
    server_name ${指到主機的網域};

    ssl_certificate /etc/letsencrypt/live/${指到主機的網域}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${指到主機的網域}/privkey.pem;  
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   Host      $http_host;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        # upstream 設定的名稱
        proxy_pass http://example;
    }
}
```

### 如何申請 HTTPS 憑證
#### 執行 generate-https-cert.sh
  1. 將所有需要申請憑證的網址放在 domains 變數內，並在 email 變數放上信箱
  2. 先將原先的所有憑證相關資料刪除，避免重覆申請相同憑證
  3. 先產生假的憑證檔案，讓 nginx 先能順利重啟
  4. 透過 certbot 的 container 換到真實的 HTTPS 憑證
  5. 再次重啟 nginx 

### 資料庫設定說明

### 如何新增資料庫 / 帳號
- 直接透過 docker-compose exec 執行
```bash
docker-compose exec mysql mysql -u root -p${DB_ROOT_PW} -e "CREATE DATABASE `${DB_NAME}`;"
docker-compose exec mysql mysql -u root -p${DB_ROOT_PW} -e "CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PW}';"
docker-compose exec mysql mysql -u root -p${DB_ROOT_PW} -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%';"
docker-compose exec mysql mysql -u root -p${DB_ROOT_PW} -e "FLUSH PRIVILEGES;"
```

### 專案、資料庫備份說明

#### project-backup.sh
- 備份執行檔，一次備份專案以及資料庫，使用方式如下
```bash
./project_backup.sh ${放備份檔案的專案路徑} ${專案來源目錄} ${資料庫名稱} ${是否為 laravel 專案，可不填}
```
- 也可放到排程任務中，定期執行此檔案

### 如何還原專案、資料庫
- 還原專案

將備份檔 `project.tgz` 還原至路徑
```bash
tar -zxvf project.tgz /path/
```

- 還原資料庫

```
docker-compose exec mysql mysql -u root -p${DB_ROOT_PW} ${DB_NAME} < project.sql
``` 

### rollback_db.sh
- 重置專案的資料庫
  > 切記先備份資料庫後再執行此檔案

```bash
sudo ./rollback_db.sh ${資料庫名稱} ${備份資料庫檔案的路徑} ${資料庫密碼} 
```

### docker-compose.yml
- mysql 設定 [docker-hub 文件](https://hub.docker.com/_/mysql)
  - image 使用 mysql:5 
  - restart:always 代表之後重新開機 docker 自動重啟
  - volumes "./mysql:/var/lib/mysql" 冒號右邊為 Container 內的 MySQL 檔案
  - MYSQL_ROOT_PASSWORD 設定 root 密碼
- nginx 設定 [docker-hub 文件](https://hub.docker.com/_/nginx)
  - image 使用 nginx:latest
  - 取得 nginx 預設檔案
  - 進入 ./config/nginx/conf.d 資料夾內，複製一份新的設定檔並命名為 {專案名稱}.conf 進行設定
- phpmyadmin 設定
  - image 使用 phpmyadmin/phpmyadmin:latest
  - 環境變數 PMA_HOST=mysql 為 phpmyadmin 連接的資料庫，以本專案為例，設定在同一個 docker-compose 內的資料庫 mysql
- certbot 設定
  - certbot 啟用時就會檢查服務的憑證是否已到期
  - 執行 ./generate-https-cert.sh 即可批次更新所有指向主機的 DNS 憑證
