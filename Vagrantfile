# -*- mode: ruby -*-
# Vagrantfile for testing Mesh Audio Network ISO

Vagrant.configure("2") do |config|
  # Use NixOS base box
  config.vm.define "mesh-builder" do |node|
    node.vm.box = "nixos/nixos-24.05-x86_64"
    
    # 4GB RAM, 4 CPUs for building
    node.vm.provider :virtualbox do |vb|
      vb.memory = "4096"
      vb.cpus = 4
    end
    
    # Synced folder for output
    node.vm.synced_folder "./output", "/vagrant_output"
    
    # Provision script
    node.vm.provision :shell do |s|
      s.inline = <<-SHELL
        # Update channels
        nix-channel --add https://nixos.org/channels/nixos-24.05 nixos
        nix-channel --update
        
        # Install git
        nix-env -iA nixos.git
        
        # Create build directory
        mkdir -p /build
        SHELL
    end
    
    node.vm.network "private_network", ip: "192.168.56.10"
  end
  
  # Multiple test nodes for mesh testing
  (1..3).each do |i|
    config.vm.define "mesh-node-#{i}" do |node|
      node.vm.box = "nixos/nixos-24.05-x86_64"
      
      node.vm.provider :virtualbox do |vb|
        vb.memory = "1024"
        vb.cpus = 1
      end
      
      node.vm.network "private_network", ip: "192.168.56.#{10+i}"
      
      node.vm.provision :shell do |s|
        s.inline = <<-SHELL
          nix-channel --add https://nixos.org/channels/nixos-24.05 nixos
          nix-channel --update
          
          # Configure mesh networking
          cat >> /etc/nixos/configuration.nix << 'EOF'
          
          # Mesh networking
          networking.interfaces.eth1.ipv4.addresses = [
            { address = "192.168.56.#{10+i}"; prefixLength = 24; }
          ];
          
          # Start mesh agent
          systemd.services.mesh-agent = {
            enable = true;
            wantedBy = [ "multi-user.target" ];
          };
          EOF
          
          nixos-rebuild switch
        SHELL
      end
    end
  end
end