# puppet-nginx
Puppet module to manage Nginx mostly through templates.

This module sets up NGINX virtual hosts according to hiera data.  It is fairly contrived in it's approach, aiming to be easy to consume for cases already predefined in the template - it is not very flexible outside of these scenarios.  Having said that, additional deployment types could be added - I expect they can remain fairly standard.

It supports Let's Encrypt to some degree (`certbot`). If told to, it will point to the certs and it will also always make it possible to `certbot` to do verification on port 80.

It requires the inclusion of [qtechnologies/phpfpm](https://github.com/Q-Technologies/puppet-phpfpm.git) and stdlib.

## Instructions
Include this module in your preferred manner.  Define some hiera data like this:
```
################################################################################
#
# NGINX Virtual Web servers
#
################################################################################
nginx::domains:
  'wiki.example.com':
    to_ssl: temporary
    letsencrypt: true
    content: php
  'webmail.example.com':
    to_ssl: temporary
    letsencrypt: true
    content: php
  'www.example.com':
    content: php
    to_ssl: permanent
    letsencrypt: true
    alternates:
      - example.com
```

Define a hash as nginx::domains.  Each key is the main domain you are hosting.  Each of these domains contains a hash with these keys:
* to_ssl - temporary or permanent.  Redirect from http to https.
* letsencrypt - true or false.  Whether to use the certs set up by `certbot`.
* content - psgi, php, owncloud, opencart.
  * psgi - proxies a PSGI application through a UNIX socket
  * php - proxies PHP-FPM through a UNIX socket
  * owncloud - proxies PHP-FPM through a UNIX socket, but with some recommended owncloud settings
  * opencart - proxies PHP-FPM through a UNIX socket, but with some recommended opencart settings
* alternates - an array of alternate server names.  They will all redirect to the main domain at this stage.


## Issues
This module is using hiera data that is embedded in the module rather than using a params class.  This may not play nicely with other modules using the same technique unless you are using hiera 3.0.6 and above (PE 2015.3.2+).
