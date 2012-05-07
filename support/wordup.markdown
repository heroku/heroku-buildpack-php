# Wordup automatically sets up Wordpress on Heroku.

Install Wordpress in < 60 seconds.

## Who are you?

1. Someone who uses Wordpress. Perhaps a developer, which is why you're reading this on GitHub.com
2. Someone who is comfortable with the command line. Perhaps a developer, which is why you're still reading this.
3. Someone who likes to help their friends get up and running with Wordpress, but hates the setup, security, and ongoing maintenance (cleaning up logs, upgrading instances, locking down Wordpress, performance, etc.)

## Here's what you get

```
1.9.2 musashi:~/workspace/mchung/wordup (master) $ time ./wordup -c foobarbazpress
-----> Setup Wordpress on Heroku.com
Cloning into 'foobarbazpress.herokuapp.com'...
remote: Counting objects: 1041, done.
remote: Compressing objects: 100% (950/950), done.
remote: Total 1041 (delta 69), reused 1041 (delta 69)
Receiving objects: 100% (1041/1041), 3.58 MiB | 863 KiB/s, done.
Resolving deltas: 100% (69/69), done.
-----> Acquiring Heroku dynos
Creating foobarbazpress... done, stack is cedar
http://foobarbazpress.herokuapp.com/ | git@heroku.com:foobarbazpress.git
Git remote heroku added
-----> Adding gizmos
-----> Adding cleardb:ignite to foobarbazpress... done, v3 (free)
-----> Engage!
Counting objects: 1041, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (950/950), done.
Writing objects: 100% (1041/1041), 3.58 MiB | 1.92 MiB/s, done.
Total 1041 (delta 69), reused 1041 (delta 69)

-----> Heroku receiving push
-----> PHP app detected
-----> Bundling Apache v2.2.19
-----> Bundling PHP v5.3.6
-----> Discovering process types
       Procfile declares types -> (none)
       Default types for PHP   -> web
-----> Compiled slug size is 24.8MB
-----> Launching... done, v5
       http://foobarbazpress.herokuapp.com deployed to Heroku

To git@heroku.com:foobarbazpress.git
 * [new branch]      master -> master
Opening http://foobarbazpress.herokuapp.com/

real	0m51.018s
user	0m6.811s
sys	0m1.018s
```

## Usage

    Usage: wordup [-c|--create] [-d|--destroy] your_wordpress_site

## Example

### Create a Wordpress instance

    wordup -c new_shiny_wordpress

### Destroy a Wordpress instance

    wordup -d new_shiny_wordpress

## How to install themes or plugins

You can't upload files to Heroku because of their ephemeral filesystem. If you want to add themes or plugins, you'll need to use the following instructions:

Copy your themes or plugins into `wp-content/plugins` or `wp-content/themes`.

    git add wp-content
    git commit -m "New widgets"
    git push heroku master

## Requirements, Gotchas, and Other notes

* Installs Wordpress 3.3.
* Requires git.
* Requires a Heroku account.
