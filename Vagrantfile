Vagrant.configure(2) do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.provision :shell, path: "bootstrap.sh"
  config.vm.network :forwarded_port, guest: 80, host: 4500
  config.vm.network :forwarded_port, guest: 81, host: 4501
  config.vm.network :forwarded_port, guest: 82, host: 4502
  
  config.vm.provider "virtualbox" do |v|
	  v.memory = 2048
	  v.cpus = 4
	end
  
  config.vm.synced_folder "www/", "/var/www", id: "vagrant-root",
    owner: "vagrant",
    group: "www-data",
    mount_options: ["dmode=775,fmode=664"]
end
