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

    upstream heroku-fcgi {
        #server 127.0.0.1:4999 max_fails=3 fail_timeout=3s;
        server unix:/tmp/heroku.fcgi.<?=getenv('PORT')?:'8080'?>.sock max_fails=3 fail_timeout=3s;
        keepalive 16;
    }
    
    server {
        listen <?=getenv('PORT')?:'8080'?>;
        
        root <?=getenv('DOCUMENT_ROOT')?:getenv('HEROKU_APP_DIR')?:getcwd()?>;
        
        error_log stderr;
        access_log /tmp/heroku.nginx_access.<?=getenv('PORT')?:'8080'?>.log;
        
        include <?=getenv('HEROKU_PHP_NGINX_CONFIG_INCLUDE')?>;
    }
}