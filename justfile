## Script for executing commands for the project.
TARGET_DIR := join(justfile_directory(), "target")
BIND_VER := "9.11.7"
TDNS_BIND_PATH := join(TARGET_DIR, "bind")

# Default target to check, build, and test all crates
default feature='': (check feature) (build feature) (test feature)

check feature='':
    cargo ws exec cargo check --all-targets --benches --examples --bins --tests {{feature}}
    cargo check --manifest-path fuzz/Cargo.toml --all-targets --benches --examples --bins --tests

build feature='':
    cargo ws exec cargo build --all-targets --benches --examples --bins --tests {{feature}}

test feature='':
    cargo ws exec cargo test --all-targets --benches --examples --bins --tests {{feature}}
   
# This tests compatibility with BIND9, TODO: support other feature sets besides openssl for tests
compatibility:
    cargo test --manifest-path tests/compatibility-tests/Cargo.toml --all-targets --benches --examples --bins --tests --no-default-features --features=none;
    cargo test --manifest-path tests/compatibility-tests/Cargo.toml --all-targets --benches --examples --bins --tests --no-default-features --features=bind;

[private]
[macos]
init-bind9-deps:
    pip install ply
    brew install openssl
    brew install wget

[private]
[linux]
init-bind9-deps:
    if apt-get --version ; then sudo apt-get install -y python3-ply ; fi

# Install BIND9
[unix]
init-bind9: init-bind9-deps
    #!/usr/bin/env bash
    set -euxo pipefail
    
    if {{TDNS_BIND_PATH}}/sbin/named -v ; then exit 0 ; fi
    
    ## This must run after OpenSSL installation    
    if openssl version ; then WITH_OPENSSL="--with-openssl=$(dirname $(dirname $(which openssl)))" ; fi
    
    mkdir -p {{TARGET_DIR}}
    
    echo "----> downloading bind"
    rm -rf {{TARGET_DIR}}/bind-{{BIND_VER}}
    wget -O {{TARGET_DIR}}/bind-{{BIND_VER}}.tar.gz https://downloads.isc.org/isc/bind9/{{BIND_VER}}/bind-{{BIND_VER}}.tar.gz
    ls -la {{TARGET_DIR}}/bind-{{BIND_VER}}.tar.gz
    tar -xzf {{TARGET_DIR}}/bind-{{BIND_VER}}.tar.gz -C {{TARGET_DIR}}
    
    echo "----> compiling bind"
    cd {{TARGET_DIR}}/bind-{{BIND_VER}}
    
    ./configure --prefix {{TDNS_BIND_PATH}} ${WITH_OPENSSL}
    make install
    cd -
    
    ${TDNS_BIND_PATH}/sbin/named -v
    
    rm ${TARGET_DIR:?}/bind-${BIND_VER}.tar.gz
    rm -rf ${TARGET_DIR:?}/bind-${BIND_VER}

# Check for the cargo-workspaces command, install if it does not exist
init-cargo-workspaces:
    @cargo ws --version || cargo install cargo-workspaces


# Initialize all tools needed for running tests, etc.
init: init-cargo-workspaces
    @echo 'all tools initialized'