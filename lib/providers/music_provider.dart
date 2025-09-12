import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../services/audio_service_integration.dart';
import '../services/music_service.dart';
import '../services/song_metadata_service.dart';
import '../services/song_storage_service.dart';
import '../services/yt_service_explode.dart';

class MusicProvider extends ChangeNotifier {
  final AudioServiceIntegration _audioServiceIntegration = AudioServiceIntegration();
  final MusicService _musicService = MusicService();
  final SongMetadataService _metadataService = SongMetadataService();
  final SongStorageService _storageService = SongStorageService();
  final YouTubeDownloadService _youtubeService = YouTubeDownloadService();

  List<Song> _songs = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  bool _disposed = false;

  List<Song> get songs => _songs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get audio service properties directly from the integration
  Song? get currentSong => _audioServiceIntegration.currentSong;
  int get currentIndex => _audioServiceIntegration.currentIndex;
  List<Song> get playlist => _audioServiceIntegration.playlist;
  
  // Player state from the audio service
  PlayerState get playerState => _audioServiceIntegration.audioPlayer?.playerState ?? PlayerState(false, ProcessingState.idle);
  Duration get currentPosition => _audioServiceIntegration.audioPlayer?.position ?? Duration.zero;
  Duration? get totalDuration => _audioServiceIntegration.audioPlayer?.duration;
  Stream<Duration> get positionStream => _audioServiceIntegration.audioPlayer?.positionStream ?? Stream.value(Duration.zero);

  final List<Song> _queue = [];
  int _queueIndex = 0;
  
  List<Song> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  // The song currently selected in the queue
  Song? get queuedSong => _queue.isNotEmpty ? _queue[_queueIndex] : null;

  Future<void> initialize() async {
    // Initialize audio service integration for notifications and lock screen controls
    await _audioServiceIntegration.initialize();
    
    // Listen to player state changes and notify UI
    final audioPlayer = _audioServiceIntegration.audioPlayer;
    if (audioPlayer != null) {
      _playerStateSubscription = audioPlayer.playerStateStream.listen((_) {
        if (_disposed) return;

        // Sync queue index with audio service
        final current = currentSong;
        final idx = _queue.indexWhere((s) => s.path == current?.path);
        if (idx != -1 && idx != _queueIndex) {
          _queueIndex = idx;
        }
        
        // Update notification with current song whenever state changes
        if (current != null) {
          _audioServiceIntegration.updateCurrentSong(current);
        }
        
        notifyListeners();
      });
    }
    
    await loadMusic();
  }

  Future<void> loadMusic() async {
    _setLoading(true);
    _clearError();

    try {
      final hasPermission = await _musicService.requestStoragePermission();
      
      if (!hasPermission) {
        _setError('Storage permission is required to access music files');
        return;
      }

      List<Song> songs = await _storageService.loadSongs();
      
      // Apply any saved metadata to the songs
      final songsWithMetadata = await _metadataService.applyMetadataToSongs(songs);
      _songs = songsWithMetadata;
      
      // Clear the queue to ensure it's in sync with the current song list
      _queue.clear();
      _queueIndex = 0;
      
      // Don't show error message if no songs - user can import manually
      
    } catch (e) {
      _setError('Error loading music: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> importMusic() async {
    try {
      final hasPermission = await _musicService.requestStoragePermission();
      
      if (!hasPermission) {
        _setError('Storage permission is required to access music files');
        return;
      }

      // Scan device for music files or let user pick files
      final newSongs = await _musicService.importMusicFiles();
      
      if (newSongs.isNotEmpty) {
        // Add new songs to storage (this handles duplicates)
        await _storageService.addSongs(newSongs);
        
        // Reload the complete song list to include new songs
        await loadMusic();
        
        // Show success message
        _clearError();
      } else {
        // If no songs found, offer to scan device storage
        final deviceSongs = await _musicService.loadMusicFiles();
        if (deviceSongs.isNotEmpty) {
          // Add found songs to storage
          await _storageService.addSongs(deviceSongs);
          
          // Reload the complete song list
          await loadMusic();
          
          _clearError();
        } else {
          _setError('No music files found. Try selecting files manually or check if music files exist on your device.');
        }
      }
    } catch (e) {
      _setError('Error importing music: $e');
    }
  }

  Future<void> playSong(Song song) async {
    try {
      // If song is not in queue, clear queue and add all songs starting from the selected one
      final songIndex = _songs.indexWhere((s) => s.path == song.path);
      if (songIndex != -1) {
        // Create a new queue starting from the selected song
        _queue.clear();
        _queue.addAll(_songs.sublist(songIndex));
        _queue.addAll(_songs.sublist(0, songIndex)); // Add songs before the selected one at the end
        _queueIndex = 0; // Selected song is now at index 0
        
        // Use the unified audio service integration
        await _audioServiceIntegration.updatePlaylist(_queue, initialIndex: _queueIndex);
        
        // Force sync the current song after play
        await syncNotificationState();
      }
      
      // notifyListeners() will be called by the stream listener
    } catch (e) {
      _setError('Error playing song: $e');
    }
  }

  Future<void> playPause() async {
    try {
      final audioPlayer = _audioServiceIntegration.audioPlayer;
      if (audioPlayer != null) {
        if (audioPlayer.playing) {
          await audioPlayer.pause();
        } else {
          await audioPlayer.play();
        }
      }
    } catch (e) {
      _setError('Error toggling play/pause: $e');
    }
  }

  Future<void> skipToNext() async {
    try {
      final audioPlayer = _audioServiceIntegration.audioPlayer;
      if (audioPlayer != null && audioPlayer.hasNext) {
        await audioPlayer.seekToNext();
        _queueIndex = (_queueIndex + 1) % _queue.length;
        notifyListeners();
      }
    } catch (e) {
      _setError('Error skipping to next: $e');
    }
  }

  Future<void> skipToPrevious() async {
    try {
      final audioPlayer = _audioServiceIntegration.audioPlayer;
      if (audioPlayer != null && audioPlayer.hasPrevious) {
        await audioPlayer.seekToPrevious();
        _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
        notifyListeners();
      }
    } catch (e) {
      _setError('Error skipping to previous: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      final audioPlayer = _audioServiceIntegration.audioPlayer;
      if (audioPlayer != null) {
        await audioPlayer.seek(position);
      }
    } catch (e) {
      _setError('Error seeking: $e');
    }
  }

  Future<void> syncNotificationState() async {
    final currentSong = this.currentSong;
    if (currentSong != null) {
      await _audioServiceIntegration.updateCurrentSong(currentSong);
    }
  }

  Future<void> updateSongDetails(Song oldSong, Song updatedSong) async {
    try {
      // Find the song in the list and update it
      final index = _songs.indexWhere((song) => song.path == oldSong.path);
      if (index != -1) {
        _songs[index] = updatedSong;
        
        // Save the metadata for persistence
        await _metadataService.saveSongDetails(updatedSong);
        
        // If this is the currently playing song, update it
        if (currentSong?.path == oldSong.path) {
          await _audioServiceIntegration.updateCurrentSong(updatedSong);
        }
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Error updating song details: $e');
    }
  }

  Future<void> updateSongThumbnail(Song song, String thumbnailPath) async {
    try {
      final updatedSong = song.copyWith(customThumbnail: thumbnailPath);
      
      final index = _songs.indexWhere((s) => s.path == song.path);
      if (index != -1) {
        _songs[index] = updatedSong;
        
        await _metadataService.saveSongDetails(updatedSong);
        
        if (currentSong?.path == song.path) {
          await _audioServiceIntegration.updateCurrentSong(updatedSong);
        }
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Error updating song thumbnail: $e');
    }
  }

  Future<void> deleteSong(Song songToDelete) async {
    try {
      // Find the song in the list
      final index = _songs.indexWhere((song) => song.path == songToDelete.path);
      if (index == -1) return;

      // Check if the song to delete is currently playing
      final isCurrentlyPlaying = currentSong?.path == songToDelete.path;
      
      // Remove from the songs list
      _songs.removeAt(index);
      
      // Remove from the queue as well
      final queueIndex = _queue.indexWhere((song) => song.path == songToDelete.path);
      if (queueIndex != -1) {
        _queue.removeAt(queueIndex);
        // Adjust queue index if needed
        if (_queueIndex >= queueIndex && _queueIndex > 0) {
          _queueIndex--;
        }
        _queueIndex = _queueIndex.clamp(0, _queue.length - 1);
      }
      
      // Remove from storage
      await _storageService.removeSong(songToDelete.path);
      
      // Remove from metadata service
      await _metadataService.deleteSongMetadata(songToDelete.path);
      
      // Handle audio service updates
      if (isCurrentlyPlaying) {
        // Stop the current playback
        final audioPlayer = _audioServiceIntegration.audioPlayer;
        if (audioPlayer != null) {
          await audioPlayer.stop();
        }
        
        // If there are still songs left in queue, update the playlist
        if (_queue.isNotEmpty) {
          await _audioServiceIntegration.updatePlaylist(_queue, initialIndex: _queueIndex);
          // Play the next song - the handler will automatically start playing
        } else {
          // No songs left, clear the playlist
          await _audioServiceIntegration.updatePlaylist([], initialIndex: 0);
        }
      } else if (_queue.isNotEmpty) {
        // Just update the playlist without changing playback
        await _audioServiceIntegration.updatePlaylist(_queue);
      } else {
        // Queue is empty, clear audio service playlist
        await _audioServiceIntegration.updatePlaylist([], initialIndex: 0);
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Error deleting song: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void setQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue
      ..clear()
      ..addAll(songs);
    _queueIndex = startIndex.clamp(0, _queue.length - 1);
    notifyListeners();

    // Update the audio service playlist and play the selected song
    // Ensures the queue is in sync with the Audio Service
    await _audioServiceIntegration.updatePlaylist(songs, initialIndex: startIndex);
    notifyListeners();
  }

  void addToQueue(Song song) {
    _queue.add(song);
    // Ensures the queue is in sync with the Audio Service
    _audioServiceIntegration.updatePlaylist(_queue);
    notifyListeners();
  }

  void removeFromQueue(Song song) {
    final wasCurrent = currentSong == song;
    _queue.remove(song);
    if (wasCurrent && _queue.isNotEmpty) {
      _queueIndex = _queueIndex.clamp(0, _queue.length - 1);
    }
    // Ensures the queue is in sync with the Audio Service
    _audioServiceIntegration.updatePlaylist(_queue);
    notifyListeners();
  }

  void playNext() {
    if (_queueIndex < _queue.length - 1) {
      _queueIndex++;
    }
    // Ensures the queue is in sync with the Audio Service
    _audioServiceIntegration.updatePlaylist(_queue);
    notifyListeners();
  }

  void playPrevious() {
    if (_queueIndex > 0) {
      _queueIndex--;
    }
    // Ensures the queue is in sync with the Audio Service
    _audioServiceIntegration.updatePlaylist(_queue);
    notifyListeners();
  }

  void playSongAt(int index) {
    if (index >= 0 && index < _queue.length) {
      _queueIndex = index;
    // Ensures the queue is in sync with the Audio Service
    _audioServiceIntegration.updatePlaylist(_queue);
      notifyListeners();
    }
  }

  /// Add a downloaded YouTube song to the library
  Future<void> addYouTubeSong(Song song) async {
    try {
      // Add to songs list
      if (!_songs.any((s) => s.path == song.path)) {
        _songs.add(song);
        
        // Save to storage
        await _storageService.saveSongs(_songs);
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to add YouTube song: $e');
    }
  }

  /// Clear all data (songs, metadata, playback state)
  Future<void> clearAllData() async {
    try {
      // Clear songs list and queue
      _songs.clear();
      _queue.clear();
      _queueIndex = 0;
      
      // Clear audio service
      await _audioServiceIntegration.updatePlaylist([]);
      
      // Clear storage
      await _storageService.clearSongs();
      
      // Clear metadata
      await _metadataService.clearAllMetadata();
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear all data: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _youtubeService.dispose();
    super.dispose();
  }
}
