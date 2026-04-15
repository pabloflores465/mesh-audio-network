# Build NixOS ISO using nix-build
FROM nixos/nix:latest

# Prevent interactive prompts
ENV NIX_CONFIG="experimental-features = nix-command flakes"
ENV HOME="/root"

# Set up
WORKDIR /build
RUN mkdir -p /output /songs

# Add channel and update
RUN nix-channel --add https://channels.nixos.org/nixos-24.05 nixos && \
    nix-channel --update

# Copy build script
COPY build_iso.sh /build/
RUN chmod +x /build/build_iso.sh

# Generate songs
COPY generate_songs.sh /build/
RUN chmod +x /build/generate_songs.sh && \
    mkdir -p /songs/all_songs /songs/node_001 && \
    /build/generate_songs.sh

# Copy software and config
COPY software/build/ /build/software/
COPY nixos-config/ /build/nixos-config/

# Build ISO - runs in background and outputs to /output
CMD /build/build_iso.sh && cp result/iso/*.iso /output/ 2>/dev/null || cp result/*.iso /output/ 2>/dev/null || ls result/