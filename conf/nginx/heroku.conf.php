daemon off;

http {
    server {
        listen <?=getenv('PORT')?:'8080'?>;
        
        root <?=getenv('DOCUMENT_ROOT')?:getenv('HEROKU_APP_DIR')?:getcwd()?>;
        
        error_log stderr;
        access_log /tmp/heroku.nginx_access.<?=getenv('PORT')?:'8080'?>.log;
        
        location ~ \.php {
            try_files $uri 404;
            
            include fastcgi_params;
            fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_pass 127.0.0.1:4999;
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