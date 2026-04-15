#!/usr/bin/env python3
"""
Download free music for mesh audio network.
Uses Jamendo API for CC0/royalty-free music.
"""

import os
import sys
import json
import random
import urllib.request
import urllib.error
import hashlib

# Configuration
TOTAL_SONGS = 2000
SONGS_DIR = "songs"
NODES_COUNT = 80
SONGS_PER_NODE = 25
MIRRORS = [
    "https://storage-new.newjamendo.com/",
    "https://api.jamendo.com/v3.0/tracks/",
]

def create_directory_structure():
    """Create songs directory structure."""
    os.makedirs(SONGS_DIR, exist_ok=True)
    for i in range(1, NODES_COUNT + 1):
        os.makedirs(f"{SONGS_DIR}/node_{i:03d}", exist_ok=True)

def download_song(url, dest_path):
    """Download a single song."""
    try:
        headers = {'User-Agent': 'MeshAudioNetwork/1.0'}
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read()
            with open(dest_path, 'wb') as f:
                f.write(data)
        return True
    except Exception as e:
        print(f"Failed to download {url}: {e}")
        return False

def generate_sample_song(dest_path, duration_sec=180):
    """Generate a sample audio file (MP3 with sine wave)."""
    try:
        import struct
        
        # Create a simple MP3 header with audio data
        # This creates a valid but simple MP3-like file
        sample_rate = 44100
        num_channels = 2
        bits_per_sample = 16
        
        # Generate WAV data
        import wave
        
        with wave.open(dest_path, 'w') as wav:
            wav.setnchannels(num_channels)
            wav.setsampwidth(bits_per_sample // 8)
            wav.setframerate(sample_rate)
            
            # Generate audio samples (sine wave with different frequencies for variety)
            freq1 = random.randint(200, 800)
            freq2 = random.randint(400, 1600)
            
            for i in range(duration_sec * sample_rate):
                t = i / sample_rate
                # Create interesting sound with multiple frequencies
                sample = int(16000 * (
                    0.5 * math.sin(2 * math.pi * freq1 * t) +
                    0.3 * math.sin(2 * math.pi * freq2 * t) +
                    0.2 * math.sin(2 * math.pi * random.randint(100, 300) * t)
                ))
                # Clamp to valid range
                sample = max(-32768, min(32767, sample))
                
                # Write as 16-bit little endian stereo
                packed = struct.pack('<hh', sample, sample)
                wav.writeframesraw(packed)
        
        return True
    except Exception as e:
        print(f"Failed to generate sample: {e}")
        return False

import math

def generate_metadata(songs_list):
    """Generate metadata for songs."""
    metadata = []
    for song in songs_list:
        metadata.append({
            "id": song["id"],
            "name": song["name"],
            "artist": song.get("artist", "Unknown"),
            "duration": song.get("duration", 180),
            "node_id": song.get("node_id", 0)
        })
    return metadata

def download_free_music():
    """Download free music from various sources."""
    songs = []
    
    # Try Jamendo API for free music
    print("Attempting to download from free sources...")
    
    # Jamendo API (free tier)
    try:
        url = "https://api.jamendo.com/v3.0/tracks/?client_id=00000000&format=json&limit=100&tags=electronic,ambient,classical&fuzzytags=free&include=musicstats"
        req = urllib.request.Request(url, headers={'User-Agent': 'MeshAudioNetwork/1.0'})
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read())
            for track in data.get('results', []):
                if track.get('audio'):
                    songs.append({
                        'id': track.get('id'),
                        'name': track.get('name'),
                        'artist': track.get('artist_name'),
                        'url': track.get('audio'),
                        'duration': track.get('duration', 180)
                    })
    except Exception as e:
        print(f"Jamendo API failed: {e}")
    
    return songs

def create_fake_songs():
    """Create placeholder songs for testing."""
    songs = []
    genres = ['ambient', 'electronic', 'classical', 'jazz', 'rock', 'folk', 'world', 'experimental']
    instruments = ['piano', 'guitar', 'synth', 'drums', 'violin', 'cello', 'flute', 'strings']
    moods = ['calm', 'energetic', 'melancholic', 'happy', 'dark', 'dreamy', 'intense', 'peaceful']
    
    for i in range(TOTAL_SONGS):
        genre = random.choice(genres)
        instrument = random.choice(instruments)
        mood = random.choice(moods)
        
        songs.append({
            'id': f"song_{i:04d}",
            'name': f"{mood.capitalize()} {instrument} {genre}",
            'artist': f"Artist {i % 100}",
            'duration': random.randint(120, 300),
            'genre': genre
        })
    
    return songs

def write_songs_to_files(songs):
    """Write songs to directory structure."""
    print(f"Writing {len(songs)} songs to {SONGS_DIR}...")
    
    # Write to all-songs directory
    all_songs_dir = f"{SONGS_DIR}/all_songs"
    os.makedirs(all_songs_dir, exist_ok=True)
    
    metadata = []
    
    for i, song in enumerate(songs):
        # Write metadata
        metadata_file = f"{all_songs_dir}/{song['id']}.json"
        with open(metadata_file, 'w') as f:
            json.dump(song, f, indent=2)
        
        # Create WAV placeholder
        wav_file = f"{all_songs_dir}/{song['id']}.wav"
        if not os.path.exists(wav_file):
            generate_sample_song(wav_file, song['duration'])
        
        if (i + 1) % 100 == 0:
            print(f"  Processed {i + 1}/{len(songs)} songs...")
    
    # Distribute to nodes (25 songs each)
    print("Distributing songs to nodes...")
    for node_idx in range(NODES_COUNT):
        node_dir = f"{SONGS_DIR}/node_{node_idx + 1:03d}"
        os.makedirs(node_dir, exist_ok=True)
        
        # Select 25 random songs for this node
        node_songs = random.sample(songs, SONGS_PER_NODE)
        
        for song in node_songs:
            src_json = f"{all_songs_dir}/{song['id']}.json"
            src_wav = f"{all_songs_dir}/{song['id']}.wav"
            
            dst_json = f"{node_dir}/{song['id']}.json"
            dst_wav = f"{node_dir}/{song['id']}.wav"
            
            if os.path.exists(src_json):
                import shutil
                shutil.copy2(src_json, dst_json)
            if os.path.exists(src_wav):
                shutil.copy2(src_wav, dst_wav)
        
        print(f"  Node {node_idx + 1:03d}: {SONGS_PER_NODE} songs assigned")
    
    # Write overall metadata
    with open(f"{SONGS_DIR}/metadata.json", 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"Done! Created {NODES_COUNT} nodes with {SONGS_PER_NODE} songs each.")

def main():
    print("=" * 60)
    print("Mesh Audio Network - Music Downloader")
    print("=" * 60)
    
    # Create directory structure
    create_directory_structure()
    
    # Try to download real songs, fall back to generated
    songs = download_free_music()
    
    if len(songs) < TOTAL_SONGS:
        print(f"Downloaded {len(songs)} songs, generating rest...")
        generated = create_fake_songs()
        songs.extend(generated)
        songs = songs[:TOTAL_SONGS]
    
    # Write songs to files
    write_songs_to_files(songs)
    
    # Print summary
    print("\n" + "=" * 60)
    print("Summary:")
    print(f"  Total songs: {len(songs)}")
    print(f"  Nodes: {NODES_COUNT}")
    print(f"  Songs per node: {SONGS_PER_NODE}")
    print(f"  Location: {os.path.abspath(SONGS_DIR)}")
    print("=" * 60)

if __name__ == "__main__":
    main()