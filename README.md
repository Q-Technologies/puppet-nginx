# puppet-nginx
Puppet module to manage standard web application configuration in Nginx.

This module sets up NGINX virtual hosts according to hiera data.  It is fairly contrived in it's approach, aiming to be easy to consume for cases already predefined in the template - it is not very flexible outside of these scenarios.  Having said that, additional deployment types could be added - I expect they can remain fairly standard.

Some features require the inclusion of [qtechnologies/psgi](https://github.com/Q-Technologies/puppet-psgi.git) and/or [qtechnologies/phpfpm](https://github.com/Q-Technologies/puppet-phpfpm.git). stdlib is always a requirement.

It supports Let's Encrypt to some degree ([certbot](https://certbot.eff.org/#pip-nginx)). It will look for domains in `/etc/letsencrypt/live` and configure NGINX to use these certs if it finds a matching domain. It will also make it possible for `certbot` to always do verification on port 80 (certbot won't do this on port 443).  It will also create a fact called: `letsencrypt_live_domains` which lists the domains in `/etc/letsencrypt/live`.

Currently only tested on SUSE, but other platforms should work with the right hiera data - especially regarding the user/group nginx runs as.

## Instructions
Include this module in your preferred manner.  E.g.:
```puppet
include nginx
```
or
```puppet
class { 'nginx': }
```


Define some hiera data like this:
```yaml
################################################################################
#
# NGINX Virtual Web servers
#
################################################################################
nginx::web_root_parent: /webroot

nginx::web_server_names:
  'wiki.example.com':
    to_ssl: temporary
    web_root: /var/www/wiki
    content: psgi
    psgi:
      server: Twiggy
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
### Module globals
`nginx::web_root_parent` is where the virtual hosts (web server names) are served from unless `web_root` is specified for a specific web server name. You can also override these defaults in hiera, if required:
```yaml
nginx::package_name: nginx
nginx::service_name: nginx
nginx::conf_dir: /etc/nginx
nginx::log_dir: /var/log/nginx
nginx::socket_dir: /var/sockets
nginx::cert_dir: /etc/nginx/certs
nginx::user: wwwrun
nginx::group: www
nginx::workers: 2
```

### Domains (Virtual Servers) to configure
Define a hash as `nginx::web_server_names` - this hash will be merged from across all your hiera data matching the node.  Each key is the main domain you are hosting (web server name/virtual host).  Each of these keys contains a hash with these keys:
* `to_ssl` - temporary or permanent.  Redirect from http to https.
* `web_root` - per web server name specified web directory root.
* `content` - psgi, php, owncloud, opencart.
  * `psgi` - proxies a PSGI application through a UNIX socket
  * `php` - proxies PHP-FPM through a UNIX socket
  * `owncloud` - proxies PHP-FPM through a UNIX socket, but with some recommended owncloud settings
  * `opencart` - proxies PHP-FPM through a UNIX socket, but with some recommended opencart settings
* `pool_ini` - for [PHP FPM](https://github.com/Q-Technologies/puppet-phpfpm.git). It can be used to overwrite the global pool ini data.  It is merged, so you only need to specify differences.
* `psgi` - parameters that can be passed to the [PSGI module](https://github.com/Q-Technologies/puppet-psgi.git) to override the PSGI global settings for this web server name only.  It is merged, so you only need to specify differences.
* `alternates` - an array of alternate server names.  They will all redirect to the main web server name, rather than acting as alternate server names in the web server.
* `environment` - the application code environment.  E.g. production, test, development, etc.  Currently only meaningful to PSGI apps by determining whether the service should be automatically started.  Defaults to production.

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
But once you do this for a domain, this puppet module will detect the new certificate and configure Nginx to use it rather than any previously configured certs (presumably self-signed).

## Issues
This module is using hiera data that is embedded in the module rather than using a params class.  This may not play nicely with other modules using the same technique unless you are using hiera 3.0.6 and above (PE 2015.3.2+).

It has only been tested on SUSE systems, using SUSE paths - patches for other platforms are welcome - we just need to create internal hiera data for the OS family.
