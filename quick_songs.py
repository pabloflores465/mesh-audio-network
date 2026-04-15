#!/usr/bin/env python3
"""Quick song generator for mesh network."""
import os
import json
import random
import struct
import math

SONGS_DIR = "songs"
NODES = 80
PER_NODE = 25
TOTAL = 2000

genres = ['ambient', 'electronic', 'classical', 'jazz', 'rock', 'folk', 'experimental']
moods = ['calm', 'energetic', 'melancholic', 'happy', 'dark', 'dreamy']

def generate_wav(path, duration=180):
    """Generate a simple WAV file."""
    sample_rate = 22050
    channels = 1
    
    with open(path, 'wb') as f:
        # WAV header
        f.write(b'RIFF')
        data_size = sample_rate * channels * 2 * duration
        f.write(struct.pack('<I', 36 + data_size))
        f.write(b'WAVE')
        f.write(b'fmt ')
        f.write(struct.pack('<I', 16))  # Subchunk1Size
        f.write(struct.pack('<H', 1))   # AudioFormat (PCM)
        f.write(struct.pack('<H', channels))
        f.write(struct.pack('<I', sample_rate))
        f.write(struct.pack('<I', sample_rate * channels * 2))  # ByteRate
        f.write(struct.pack('<H', channels * 2))  # BlockAlign
        f.write(struct.pack('<H', 16))  # BitsPerSample
        f.write(b'data')
        f.write(struct.pack('<I', data_size))
        
        # Generate audio data
        freq = random.randint(200, 800)
        for i in range(sample_rate * duration):
            t = i / sample_rate
            # Simple sine wave with some variation
            val = int(8000 * math.sin(2 * math.pi * freq * t))
            f.write(struct.pack('<h', val))
    
    return True

print("Generating songs...")
songs = []
for i in range(TOTAL):
    genre = random.choice(genres)
    mood = random.choice(moods)
    songs.append({
        'id': f'song_{i:04d}',
        'name': f'{mood.capitalize()} {genre}',
        'artist': f'Artist_{i % 100}',
        'duration': random.randint(120, 300),
        'genre': genre
    })
    
print(f"Created {len(songs)} song definitions")

# Save all songs metadata
with open(f"{SONGS_DIR}/metadata.json", 'w') as f:
    json.dump(songs, f, indent=2)

# Generate WAV files (just a few as placeholders)
print("Generating sample WAV files...")
count = 0
for song in songs[:100]:  # Generate first 100 as actual WAVs
    wav_path = f"{SONGS_DIR}/all_songs/{song['id']}.wav"
    if not os.path.exists(wav_path):
        generate_wav(wav_path, song['duration'])
        count += 1
        if count % 20 == 0:
            print(f"  Generated {count}/100 WAV files")
print(f"Generated {count} WAV files")

# Create metadata files for all songs
print("Creating metadata files...")
for song in songs:
    meta_path = f"{SONGS_DIR}/all_songs/{song['id']}.json"
    with open(meta_path, 'w') as f:
        json.dump(song, f)

# Distribute to nodes (copy references)
print("Distributing to nodes...")
import shutil
for node_idx in range(1, NODES + 1):
    node_dir = f"{SONGS_DIR}/node_{node_idx:03d}"
    os.makedirs(node_dir, exist_ok=True)
    
    # Select 25 songs for this node
    node_songs = random.sample(songs, PER_NODE)
    for song in node_songs:
        # Copy metadata
        src_meta = f"{SONGS_DIR}/all_songs/{song['id']}.json"
        dst_meta = f"{node_dir}/{song['id']}.json"
        if os.path.exists(src_meta):
            shutil.copy2(src_meta, dst_meta)
        
        # Copy WAV if exists
        src_wav = f"{SONGS_DIR}/all_songs/{song['id']}.wav"
        dst_wav = f"{node_dir}/{song['id']}.wav"
        if os.path.exists(src_wav):
            shutil.copy2(src_wav, dst_wav)
        elif count < TOTAL:
            # Generate a tiny placeholder
            generate_wav(dst_wav, song['duration'])
    
    if node_idx % 10 == 0:
        print(f"  Node {node_idx}/{NODES} configured")

print("\n✅ Done! Songs ready in:", os.path.abspath(SONGS_DIR))
print(f"   Total songs: {len(songs)}")
print(f"   Nodes: {NODES}")
print(f"   Songs per node: {PER_NODE}")