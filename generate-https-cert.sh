#!/bin/bash

# 此腳本為批次產生 HTTPS 憑證使用
# 原先參考的作法是一次為一個網域產生一個憑證，但是本次案例是有多網域透過 Reverse Proxy 進入不同的專案，因此需要批次產生憑證

# 將所有需要申請憑證的網址放在 domains 變數內，並放上信箱
domains=(example.com example2.com)
email=
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

# 先將原先的所有憑證相關資料刪除，否則更新憑證時，certbot 會跳過原先設定好的資料夾新建用不到的資料夾
sudo rm -r ./certbot/conf/*

# 取得假的憑證檔案，為了要讓 nginx 在啟動前先讀取得憑證，因此需要先產生假憑證，讓 nginx 能夠順利啟動。 
for domain in "${domains[@]}"; do
    echo $domain;
    # 在 certbot 設定檔底下產生某網域憑證的對應路徑，例如 ./certbot/conf/live/dev-erp.skymirror.com.tw/ 
    mkdir -p ./certbot/conf/live/$domain/
    # 產生假憑證的指令，nginx 的 .conf 檔案需先設定好該憑證的路徑
    sudo docker-compose run --rm --entrypoint "openssl req -x509 -nodes -newkey rsa:4096 -days 1 -keyout '/etc/letsencrypt/live/$domain/privkey.pem' -out '/etc/letsencrypt/live/$domain/fullchain.pem' -subj '/CN=localhost'" certbot   
done

# 重啟 nginx，確保設定檔都有讀到假憑證
sudo docker-compose restart nginx

# 取得真實的憑證，讓 live 底下的所有網域都換成 letsencrypt 憑證
for domain in "${domains[@]}"; do
    # 刪除原先假憑證的資料夾
    rm -r ./certbot/conf/live/$domain/
    # 透過 docker-compose 取得真實的憑證資料
    if [ $staging != "0" ]; then staging_arg="--staging"; fi
    sudo docker-compose run --rm --entrypoint "certbot certonly --non-interactive --webroot -w /var/www/certbot $staging_arg --email $email -d $domain --rsa-key-size 4096 --agree-tos --force-renewal --break-my-certs" certbot
done

# 再次重啟 nginx，並測試網站是否有拿到真實憑證
sudo docker-compose restart nginx

