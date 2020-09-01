# This custom fact shows the domains active with Let's Encrypt using certbot
#
# Author: matt@Q-Technologies.com.au

require 'puppet'

Facter.add('letsencrypt_live_domains') do
  confine kernel: 'Linux'
  setcode do
    dirname = '/etc/letsencrypt/live'
    if File.directory?(dirname) && File.readable?(dirname)
      Dir.entries(dirname).grep(%r{^[^.]})
    else
      []
    end
  end
end
