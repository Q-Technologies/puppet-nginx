class nginx (
  # Class parameters are populated from module hiera data - but can be overridden by global hiera
  String   $conf_dir,
  String   $log_dir,
  String   $socket_dir,
  String   $cert_dir,

  # These class parameters are populated from global hiera data
  String   $vhosts_conf_dir = "${conf_dir}/vhosts.d",
  Data     $domains         = {},
  String   $web_root_parent = "/websites",
){

  # Make sure the parent directory exist - plus manage all virtual hosts
  file { "${conf_dir}":
    ensure  => directory,
  } ->
  file { "${vhosts_conf_dir}":
    ensure  => directory,
    recurse => true,
    purge   => true,
  }

  # NGINX main config
  file { "${conf_dir}/nginx.conf":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    notify  => Service['nginx'],
    require => File[$conf_dir],
    content => epp('nginx/nginx_conf.epp', { 
      vhosts_conf_dir => $vhosts_conf_dir,
      log_dir         => $log_dir,
      web_root_parent => $web_root_parent,
    } ),
  }

  # NGINX Virtual Host definition
  $domains.each | $domain, $config | {
    # Create PHP-FPM pool for PHP powered apps
    if $config['content'] =~ /php|owncloud|opencart/ {
      phpfpm::pool { $domain:
        socket_dir => $socket_dir,
        pool_ini   => $config['pool_ini'],
      }
    }
    # Is letsencrypt active for this domain
    $letsencrypt = ! empty( grep( $facts['letsencrypt_live_domains'], $domain ) )

    # Find the web root - use the global one if it's not specified per domain
    if $config['web_root'] and $config['web_root'] != '' {
      $web_root = $config['web_root']
    } else {
      $web_root = "${web_root_parent}/${domain}"
    }

    # Write the virtual host config file from a template
    file { "${vhosts_conf_dir}/${domain}.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      notify  => Service['nginx'],
      require => File[$vhosts_conf_dir],
      content => epp('nginx/vhost_conf.epp', { 
        domain      => $domain, config => $config,
        web_root    => $web_root,
        log_dir     => $log_dir,
        socket_dir  => $socket_dir,
        cert_dir    => $cert_dir,
        letsencrypt => $letsencrypt,
      } ),
    }
  }

  service { "nginx":
    ensure  => true,
    enable  => true,
  }

  package { 'nginx':
    ensure  => installed,
  }
  
}
