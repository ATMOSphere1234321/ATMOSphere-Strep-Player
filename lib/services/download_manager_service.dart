import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/yt_service_explode.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadItem {
  final String id;
  final String url;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  double progress;
  DownloadStatus status;
  Song? completedSong;
  String? errorMessage;

  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.completedSong,
    this.errorMessage,
  });

  DownloadItem copyWith({
    String? id,
    String? url,
    String? title,
    String? artist,
    String? thumbnailUrl,
    double? progress,
    DownloadStatus? status,
    Song? completedSong,
    String? errorMessage,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      completedSong: completedSong ?? this.completedSong,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadManagerService extends ChangeNotifier {
  static final DownloadManagerService _instance = DownloadManagerService._internal();
  factory DownloadManagerService() => _instance;
  DownloadManagerService._internal();

  final YouTubeDownloadService _youtubeService = YouTubeDownloadService();
  final Map<String, DownloadItem> _downloads = {};
  final Map<String, StreamController<DownloadItem>> _progressControllers = {};
  bool _isProcessing = false;

  List<DownloadItem> get downloads => _downloads.values.toList();
  List<DownloadItem> get activeDownloads => 
    _downloads.values.where((item) => 
      item.status == DownloadStatus.downloading || 
      item.status == DownloadStatus.queued
    ).toList();
  
  List<DownloadItem> get completedDownloads =>
    _downloads.values.where((item) => item.status == DownloadStatus.completed).toList();

  Stream<DownloadItem> getDownloadStream(String id) {
    _progressControllers[id] ??= StreamController<DownloadItem>.broadcast();
    return _progressControllers[id]!.stream;
  }

  Future<String> startDownload({
    required String url,
    required String title,
    required String artist,
    String? thumbnailUrl,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final downloadItem = DownloadItem(
      id: id,
      url: url,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
    );

    _downloads[id] = downloadItem;
    _progressControllers[id] = StreamController<DownloadItem>.broadcast();
    
    notifyListeners();
    
    // Start processing queue if not already processing
    if (!_isProcessing) {
      _processDownloadQueue();
    }

    return id;
  }

  Future<void> _processDownloadQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (true) {
      // Find next queued download
      final queuedDownloads = _downloads.values
          .where((item) => item.status == DownloadStatus.queued)
          .toList();
      
      if (queuedDownloads.isEmpty) break;
      
      final queuedDownload = queuedDownloads.first;

      await _processDownload(queuedDownload);
    }

    _isProcessing = false;
  }

  Future<void> _processDownload(DownloadItem downloadItem) async {
    try {
      // Update status to downloading
      _updateDownloadItem(downloadItem.id, downloadItem.copyWith(
        status: DownloadStatus.downloading,
      ));

      // Start the actual download
      final song = await _youtubeService.downloadYouTubeAudio(
        downloadItem.url,
        onProgress: (progress) {
          _updateDownloadItem(downloadItem.id, downloadItem.copyWith(
            progress: progress,
          ));
        },
      );

      if (song != null) {
        // Download completed successfully
        _updateDownloadItem(downloadItem.id, downloadItem.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          completedSong: song,
        ));
      } else {
        // Download failed
        _updateDownloadItem(downloadItem.id, downloadItem.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Download failed',
        ));
      }
    } catch (e) {
      // Download failed with exception
      _updateDownloadItem(downloadItem.id, downloadItem.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
    }
  }

  void _updateDownloadItem(String id, DownloadItem updatedItem) {
    _downloads[id] = updatedItem;
    _progressControllers[id]?.add(updatedItem);
    notifyListeners();
  }

  void cancelDownload(String id) {
    final item = _downloads[id];
    if (item != null && (item.status == DownloadStatus.queued || item.status == DownloadStatus.downloading)) {
      _updateDownloadItem(id, item.copyWith(
        status: DownloadStatus.cancelled,
      ));
    }
  }

  void removeDownload(String id) {
    _downloads.remove(id);
    _progressControllers[id]?.close();
    _progressControllers.remove(id);
    notifyListeners();
  }

  void clearCompleted() {
    final completedIds = _downloads.entries
        .where((entry) => entry.value.status == DownloadStatus.completed)
        .map((entry) => entry.key)
        .toList();
    
    for (final id in completedIds) {
      removeDownload(id);
    }
  }

  @override
  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    super.dispose();
  }
}
