# Class to configure the NGINX web server (proxy engine)
class nginx (
  # Class parameters are populated from module hiera data - but can be overridden by global hiera
  String   $config_dir,
  String   $log_dir,
  String   $socket_dir,
  String   $cert_dir,
  String   $user,
  String   $group,
  Integer  $workers,
  Integer  $snh_bucket_size,
  String   $package_name,
  String   $service_name,

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
      user            => $user,
      group           => $group,
      workers         => $workers,
      snh_bucket_size => $snh_bucket_size,
    } ),
  }

  # NGINX Virtual Host definition
  $web_server_names.each | $main_server_name, $config | {
    # Find the web root - use the global one if it's not specified per main_server_name
    if $config['web_root'] and $config['web_root'] != '' {
      $web_root = $config['web_root']
    } else {
      $web_root = "${web_root_parent}/${main_server_name}"
    }

    # Create PHP-FPM pool for PHP powered apps
    if $config['content'] =~ /php|owncloud|opencart/ {
      # Direct user input should override our calculated data - keys in hashes to the right take precedence
      $new_config = deep_merge( { user => $user, group => $group }, $config['pool_ini'] )
      phpfpm::pool { $main_server_name:
        socket_dir => $socket_dir,
        pool_ini   => $new_config,
      }
    }

    # Create the systemd service files to start the PSGI powered apps
    if $config['content'] =~ /psgi/ {
      if $config['app_environment'] == undef {
        $app_environment = ''
      } else {
        $app_environment = $config['app_environment']
      }
      if $config['psgi'].is_a(Hash) {
        # Direct user input should override our calculated data - keys in hashes to the right take precedence
        $new_config = deep_merge( { web_root => $web_root, app_environment => $app_environment, user => $user, group => $group }, $config['psgi'] )
        create_resources( psgi::service, { $main_server_name => $new_config }, {} )
      } else {
        psgi::service { $main_server_name:
          web_root        => $web_root,
          app_environment => $app_environment,
          user            => $user,
          group           => $group,
        }
      }
    }

    # Is letsencrypt active for this main_server_name
    $letsencrypt = ! empty( grep( $facts['letsencrypt_live_domains'], $main_server_name ) )

    # Write the virtual host config file from a template
    file { "${vhosts_conf_dir}/${main_server_name}.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      notify  => Service[$service_name],
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

  service { $service_name:
    ensure => true,
    enable => true,
  }

  package { $package_name:
    ensure  => installed,
  }

}
