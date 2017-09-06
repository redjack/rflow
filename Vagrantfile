# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
#  config.vm.define 'centos62' do |c|
#    c.vm.box = 'jstoneham/rflow-centos62'
#  end
#  config.vm.define 'centos64' do |c|
#    c.vm.box = 'box-cutter/centos64'
#  end
#  config.vm.define 'centos65' do |c|
#    c.vm.box = 'chef/centos-6.5'
#  end
  config.vm.define 'centos67' do |c|
    c.vm.box = 'boxcutter/centos67'
  end

  config.vm.synced_folder '.', '/rflow'
  # bring over rflow examples; use rsync so it's safe to create IPCs in the rflow-examples directory
  # (that is, avoid NFS)
  # run 'vagrant rsync-auto' to get syncing to happen automatically
  config.vm.synced_folder '../rflow_examples', '/rflow_examples', type: 'rsync', rsync__exclude: '.git/'
  config.vm.synced_folder '../rflow-components-http', '/rflow-components-http'

  # forward http for rflow testing
  config.vm.network 'forwarded_port', guest: 8000, host: 8000

  # install RPM dependencies for rflow and zeromq
  config.vm.provision 'shell', privileged: true, inline: <<-EOS
    curl -OL https://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
    rpm -ivh epel-release-6-8.noarch.rpm
    yum -y install libyaml-devel patch libffi-devel glibc-headers autoconf gcc-c++ glibc-devel readline-devel zlib-devel openssl-devel automake libtool bison git sqlite-devel rpm-build libuuid-devel vim
  EOS

  # build zeromq as vagrant user
  config.vm.provision 'shell', privileged: false, inline: <<-EOS
    curl -OL https://archive.org/download/zeromq_3.2.4/zeromq-3.2.4.tar.gz
    rpmbuild -tb zeromq-3.2.4.tar.gz
  EOS

  # install zeromq
  config.vm.provision 'shell', privileged: true, inline: <<-EOS
    rpm -ivh ~vagrant/rpmbuild/RPMS/x86_64/zeromq-*
  EOS

  # set up RVM and bundler
  config.vm.provision 'shell', privileged: false, inline: <<-EOS
    rm -f .profile
    gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
    curl -sSL https://get.rvm.io | bash -s stable
    source .rvm/scripts/rvm
    rvm install `cat /rflow/.ruby-version`
    cd /rflow
    bundle update
  EOS
end
