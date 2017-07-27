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

    server_tokens off;

    fastcgi_buffers 256 4k;

    # define an easy to reference name that can be used in fastgi_pass
    upstream heroku-fcgi {
        #server 127.0.0.1:4999 max_fails=3 fail_timeout=3s;
        server unix:/tmp/heroku.fcgi.<?=getenv('PORT')?:'8080'?>.sock max_fails=3 fail_timeout=3s;
        keepalive 16;
    }

    map $uri $blogname{
        ~^(?P<blogpath>/[^/]+/)files/(.*)       $blogpath ;
    }

    map $blogname $blogid{
        default -999;

        #Ref: http://wordpress.org/extend/plugins/nginx-helper/
        #include /var/www/wordpress/wp-content/plugins/nginx-helper/map.conf ;
    }

    server {
        rewrite_log on;

        # define an easy to reference name that can be used in try_files
        location @heroku-fcgi {
            include fastcgi_params;

            fastcgi_split_path_info ^(.+\.php)(/.*)$;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            # try_files resets $fastcgi_path_info, see http://trac.nginx.org/nginx/ticket/321, so we use the if instead
            fastcgi_param PATH_INFO $fastcgi_path_info if_not_empty;

            if (!-f $document_root$fastcgi_script_name) {
                # check if the script exists
                # otherwise, /foo.jpg/bar.php would get passed to FPM, which wouldn't run it as it's not in the list of allowed extensions, but this check is a good idea anyway, just in case
                return 404;
            }

            fastcgi_pass heroku-fcgi;
        }

        # TODO: use X-Forwarded-Host? http://comments.gmane.org/gmane.comp.web.nginx.english/2170
        server_name localhost;
        listen <?=getenv('PORT')?:'8080'?>;
        # FIXME: breaks redirects with foreman
        port_in_redirect off;

        root "<?=getenv('DOCUMENT_ROOT')?:getenv('HEROKU_APP_DIR')?:getcwd()?>";

        error_log stderr;
        access_log /tmp/heroku.nginx_access.<?=getenv('PORT')?:'8080'?>.log;

        include "<?=getenv('HEROKU_PHP_NGINX_CONFIG_INCLUDE')?>";

        index index.php;

		# Global restrictions configuration file.
        # Designed to be included in any server {} block.
        location = /favicon.ico {
            log_not_found off;
            access_log off;
        }

        location = /robots.txt {
            allow all;
            log_not_found off;
            access_log off;
        }

	# Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
        # Keep logging the requests to parse later (or to pass to firewall utilities such as fail2ban)
        location ~ /\. {
            deny all;
        }

	# BEGIN W3TC CDN
	location ~ \.(ttf|ttc|otf|eot|woff|font.css)$ {
	   add_header Access-Control-Allow-Origin "*";
	}
	# END W3TC CDN
	# BEGIN W3TC Page Cache cache
	location ~ /wp-content/cache/page_enhanced.*html$ {
	    add_header Vary Cookie;
	}
	# END W3TC Page Cache cache
	# BEGIN W3TC Page Cache core
	set $w3tc_rewrite 1;
	if ($request_method = POST) {
	    set $w3tc_rewrite 0;
	}
	if ($query_string != "") {
	    set $w3tc_rewrite 0;
	}
	if ($request_uri !~ \/$) {
	    set $w3tc_rewrite 0;
	}
	if ($http_cookie ~* "(comment_author|wp\-postpass|w3tc_logged_out|wordpress_logged_in)") {
	    set $w3tc_rewrite 0;
	}
	if ($http_cookie ~* "(w3tc_preview)") {
	    set $w3tc_rewrite _preview;
	}
	set $w3tc_ref "";
	if ($http_cookie ~* "w3tc_referrer=.*(ask\.com|bing\.com|google\.com|msn\.com|yahoo\.com)") {
	    set $w3tc_ref _search_engines;
	}
	set $w3tc_ssl "";
	if ($scheme = https) {
	    set $w3tc_ssl _ssl;
	}
	set $w3tc_ext "";
	if (-f "$document_root/wp-content/cache/page_enhanced/$http_host/$request_uri/_index$w3tc_ref$w3tc_ssl$w3tc_rewrite.html") {
	    set $w3tc_ext .html;
	}
	if (-f "$document_root/wp-content/cache/page_enhanced/$http_host/$request_uri/_index$w3tc_ref$w3tc_ssl$w3tc_rewrite.xml") {
	    set $w3tc_ext .xml;
	}
	if ($w3tc_ext = "") {
	  set $w3tc_rewrite 0;
	}
	if ($w3tc_rewrite = 1) {
	    rewrite .* "/wp-content/cache/page_enhanced/$http_host/$request_uri/_index$w3tc_ref$w3tc_ssl$w3tc_rewrite$w3tc_ext" last;
	}
	# END W3TC Page Cache core


	# Deny access to any files with a .php extension in the uploads directory
        # Works in sub-directory installs and also in multisite network
        # Keep logging the requests to parse later (or to pass to firewall utilities such as fail2ban)
        location ~* /(?:uploads|files)/.*\.php$ {
            deny all;
        }

		#
		#
		location ~ ^(/[^/]+/)?files/(.+) {
            try_files /app/html/wp-content/blogs.dir/$blogid/files/$2 /wp-includes/ms-files.php?file=$2 ;
            access_log off;     log_not_found off; expires max;
        }

        #avoid php readfile()
		#
        location ^~ /blogs.dir {
            internal;
            alias /app/html/wp-content/blogs.dir ;
            access_log off;     log_not_found off; expires max;
        }

		#
		#
        if (!-e $request_filename) {
            rewrite /wp-admin$ $scheme://$host$uri/ permanent;
            rewrite ^(/[^/]+)?(/wp-.*) $2 last;
            rewrite ^(/[^/]+)?(/.*\.php) $2 last;
        }

		#
		#
        location / {
            try_files $uri $uri/ /index.php?$args;
        }

		#
		#
		location ~ \.php {
            try_files @heroku-fcgi @heroku-fcgi;
        }

        <?=getenv('PASSWD')?:'auth_basic "Restricted";auth_basic_user_file /app/html/.htpasswd'?>;
    }
}
