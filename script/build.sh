#!/bin/bash

# https://guides.rubyonrails.org/install_ruby_on_rails.html

# Install dependencies with apt
sudo apt update
sudo apt install -y build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev git

# Install Mise version manager
curl https://mise.run | sh

# Ensure Mise is added to PATH and activated
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> ~/.bashrc

# Reload shell configuration
source ~/.bashrc

eval "$($HOME/.local/bin/mise activate bash)"

# Verify Mise installation
# mise doctor

# Install Ruby globally with Mise
mise use -g ruby@3

gem install rails

sudo apt install -y redis-server