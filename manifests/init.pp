# Class to configure the NGINX web server (proxy engine)
class nginx (
  # Class parameters are populated from module hiera data - but can be overridden by global hiera
  String   $config_dir,
  String   $log_dir,
  String   $socket_dir,
  String   $cert_dir,

  # These class parameters are populated from global hiera data
  String   $vhosts_conf_dir  = "${config_dir}/vhosts.d",
  String   $web_root_parent  = '/websites',
){
  include stdlib

  # Perform a hiera_hash to make sure we collect all data.  Also allow for previously used parameter name
  $web_server_names = deep_merge( hiera_hash( 'nginx::domains', {} ), hiera_hash( 'nginx::web_server_names', {} ) )

  # Make sure the parent directory exist - plus manage all virtual hosts
  file { $config_dir:
    ensure  => directory,
  } ->
  file { $vhosts_conf_dir:
    ensure  => directory,
    recurse => true,
    purge   => true,
  }

  # NGINX main config
  file { "${config_dir}/nginx.conf":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    notify  => Service['nginx'],
    require => File[$config_dir],
    content => epp('nginx/nginx_conf.epp', {
      vhosts_conf_dir => $vhosts_conf_dir,
      log_dir         => $log_dir,
      web_root_parent => $web_root_parent,
    } ),
  }

  # NGINX Virtual Host definition
  $web_server_names.each | $main_server_name, $config | {
    # Create PHP-FPM pool for PHP powered apps
    if $config['content'] =~ /php|owncloud|opencart/ {
      phpfpm::pool { $main_server_name:
        socket_dir => $socket_dir,
        pool_ini   => $config['pool_ini'],
      }
    }

    # Create the systemd service files to start the PSGI powered apps
    if $config['content'] =~ /psgi/ {
      # FIX - web_root should come from the parent data - i.e the main_server_name
      # FIX - We should add an option to only do web_server_names marked as production as non-prod presumably 
      #           want to be started/stopped manually.
      if $config['psgi'].is_a(Hash) {
        create_resources( psgi::service, { $main_server_name => $config['psgi'] }, {} )
      } else {
        psgi::service { $main_server_name: }
      }
    }

    # Is letsencrypt active for this main_server_name
    $letsencrypt = ! empty( grep( $facts['letsencrypt_live_domains'], $main_server_name ) )

    # Find the web root - use the global one if it's not specified per main_server_name
    if $config['web_root'] and $config['web_root'] != '' {
      $web_root = $config['web_root']
    } else {
      $web_root = "${web_root_parent}/${main_server_name}"
    }

    # Write the virtual host config file from a template
    file { "${vhosts_conf_dir}/${main_server_name}.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      notify  => Service['nginx'],
      require => File[$vhosts_conf_dir],
      content => epp('nginx/vhost_conf.epp', {
        web_server_name => $main_server_name,
        config          => $config,
        web_root        => $web_root,
        log_dir         => $log_dir,
        socket_dir      => $socket_dir,
        cert_dir        => $cert_dir,
        letsencrypt     => $letsencrypt,
      } ),
    }
  }

  service { 'nginx':
    ensure => true,
    enable => true,
  }

  package { 'nginx':
    ensure  => installed,
  }

}
