# puppet-nginx
Puppet module to manage standard web application configuration in Nginx.

This module sets up NGINX virtual hosts according to hiera data.  It is fairly contrived in it's approach, aiming to be easy to consume for cases already predefined in the template - it is not very flexible outside of these scenarios.  Having said that, additional deployment types could be added - I expect they can remain fairly standard.

It requires the inclusion of [qtechnologies/phpfpm](https://github.com/Q-Technologies/puppet-phpfpm.git) and stdlib.

It supports Let's Encrypt to some degree ([certbot](https://certbot.eff.org/#pip-nginx)). It will look for domains in `/etc/letsencrypt/live` and configure NGINX to use these certs if it finds a matching domain. It will also always make it possible for `certbot` to do verification on port 80.  It will also create a fact called: `letsencrypt_live_domains` which lists the domains in `/etc/letsencrypt/live`.

Currently only tested on SUSE, but other platforms should work with the right hiera data.

## Instructions
Include this module in your preferred manner.  E.g.:
```puppet
include nginx
```

Define some hiera data like this:
```yaml
################################################################################
#
# NGINX Virtual Web servers
#
################################################################################
nginx::web_root_parent: /webroot

nginx::domains:
  'wiki.example.com':
    to_ssl: temporary
    web_root: /var/www/wiki
    content: php
  'webmail.example.com':
    content: php
  'www.example.com':
    content: php
    pool_ini:
      pm.max_children: 12
    to_ssl: permanent
    alternates:
      - example.com
```

Define a hash as `nginx::domains`.  Each key is the main domain you are hosting.  Each of these domains contains a hash with these keys:
* `to_ssl` - temporary or permanent.  Redirect from http to https.
* `web_root` - per domain specified web directory root.
* `pool_ini` - for PHP FPM. It can be used tooverwrite the global pool ini data.  It is merged, so you only need to specify differences.
* `content` - psgi, php, owncloud, opencart.
  * `psgi` - proxies a PSGI application through a UNIX socket
  * `php` - proxies PHP-FPM through a UNIX socket
  * `owncloud` - proxies PHP-FPM through a UNIX socket, but with some recommended owncloud settings
  * `opencart` - proxies PHP-FPM through a UNIX socket, but with some recommended opencart settings
* `alternates` - an array of alternate server names.  They will all redirect to the main domain at this stage.

`nginx::web_root_parent` is where the domains are served from unless `web_root` is specified for a domain. You can also overide these defaults in hiera, if required:
```yaml
nginx::conf_dir: /etc/nginx
nginx::log_dir: /var/log/nginx
```

### Let's Encrypt (certbot)
This module will not automatically configure Let's Encrypt.  You need to do it manually using instructions on [this page](https://certbot.eff.org/#pip-nginx), in short do this:
```bash
# Once only
wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto

# Repeat for each domain group (certificate request)
./path/to/certbot-auto certonly --webroot \
        -w /webroot/example -d example.com -d www.example.com \
        -w /webroot/thing -d thing.is -d m.thing.is
```

## Issues
This module is using hiera data that is embedded in the module rather than using a params class.  This may not play nicely with other modules using the same technique unless you are using hiera 3.0.6 and above (PE 2015.3.2+).

It has only been tested on SUSE systems, using SUSE paths - patches for other platforms are welcome - we just need to create internal hiera data for the OS family.
