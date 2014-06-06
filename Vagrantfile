# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "chef/centos-6.5"

  # forward http for rflow testing
  config.vm.network "forwarded_port", guest: 8000, host: 8000

  # install RPM dependencies for rflow and zeromq
  config.vm.provision "shell", privileged: true, inline: <<-EOS
    curl -O https://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
    rpm -ivh epel-release-6-8.noarch.rpm
    yum -y install libyaml-devel patch libffi-devel glibc-headers autoconf gcc-c++ glibc-devel readline-devel zlib-devel openssl-devel automake libtool bison git sqlite-devel rpm-build libuuid-devel
  EOS

  # build zeromq as vagrant user
  config.vm.provision "shell", privileged: false, inline: <<-EOS
    curl -O http://download.zeromq.org/zeromq-3.2.4.tar.gz
    rpmbuild -tb zeromq-3.2.4.tar.gz
  EOS

  # install zeromq
  config.vm.provision "shell", privileged: true, inline: <<-EOS
    rpm -ivh ~vagrant/rpmbuild/RPMS/x86_64/zeromq-*
  EOS

  # set up RVM and bundler
  config.vm.provision "shell", privileged: false, inline: <<-EOS
    rm .profile
    curl -sSL https://get.rvm.io | bash -s stable
    source .rvm/scripts/rvm
    rvm install `cat /vagrant/.ruby-version`
    cd /vagrant
    bundle update
  EOS
end
