#!/bin/bash
# Generate songs metadata for ISO build
# Creates 2000 small JSON files instead of large audio files

echo "Generating song metadata files..."

mkdir -p /songs/all_songs /songs/node_001

for i in $(seq 0 1999); do
    id=$(printf "song_%04d" $i)
    genre=$([ $i -lt 400 ] && echo "ambient" || \
           [ $i -lt 800 ] && echo "electronic" || \
           [ $i -lt 1200 ] && echo "classical" || \
           [ $i -lt 1600 ] && echo "jazz" || \
           [ $i -lt 2000 ] && echo "rock" || echo "experimental")
    
    cat > "/songs/all_songs/${id}.json" << EOF
{
  "id": "${id}",
  "name": "Song ${i}",
  "artist": "Artist $((i % 100))",
  "duration": $((150 + i % 150)),
  "genre": "${genre}",
  "node_assignment": $((i % 80 + 1))
}
EOF
done

# Copy 50 songs to node_001 as example (all songs will be on ISO)
cp /songs/all_songs/*.json /songs/node_001/ 2>/dev/null || true

echo "✅ Created $(ls /songs/all_songs/*.json | wc -l) song metadata files"
echo "   Each node will have 25 songs assigned from these 2000"
echo "   Total disk space: $(du -sh /songs | cut -f1)"