http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen <?=getenv('PORT')?:'8080'?>;
        
        root <?=getenv('DOCUMENT_ROOT')?:getenv('HEROKU_APP_DIR')?:getcwd()?>;
        
        error_log stderr;
        access_log /tmp/heroku.nginx_access.<?=getenv('PORT')?:'8080'?>.log;
        
        location ~ \.php {
            try_files $uri 404;
            
            include fastcgi_params;
            fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
            # fastcgi_pass 127.0.0.1:4999;
            fastcgi_pass unix:/tmp/heroku.fcgi.<?=getenv('PORT')?:'8080'?>.sock;
            fastcgi_buffers 256 4k;
        }
        
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
        
        location / {
            index  index.php index.html index.htm;
        }
    }
}