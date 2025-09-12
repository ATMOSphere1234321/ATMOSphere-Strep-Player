import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/dracula_theme.dart';
import '../services/yt_service_explode.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';

class YouTubeDownloadDialog extends StatefulWidget {
  final Function(Song) onSongDownloaded;

  const YouTubeDownloadDialog({
    super.key,
    required this.onSongDownloaded,
  });

  @override
  State<YouTubeDownloadDialog> createState() => _YouTubeDownloadDialogState();
}

class _YouTubeDownloadDialogState extends State<YouTubeDownloadDialog> {
  final TextEditingController _urlController = TextEditingController();
  final YouTubeDownloadService _downloadService = YouTubeDownloadService();
  
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  VideoInfo? _videoInfo;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  Future<void> _getVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Dismiss keyboard after getting video info
    _dismissKeyboard();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _videoInfo = null;
    });

    if (!_downloadService.isValidYouTubeUrl(url)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid YouTube URL';
      });
      return;
    }

    final videoInfo = await _downloadService.getVideoInfo(url);
    
    setState(() {
      _isLoading = false;
      _videoInfo = videoInfo;
      if (videoInfo == null) {
        _errorMessage = 'Could not fetch video information';
      }
    });
  }

  Future<void> _downloadAudio() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    // Start background download
    _downloadService.downloadYouTubeAudio(
      url,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
    ).then((song) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = song != null;
        });

        if (song != null) {
          widget.onSongDownloaded(song);
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Downloaded: ${song.title}',
                style: TextStyle(color: DraculaTheme.background),
              ),
              backgroundColor: DraculaTheme.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Failed to download audio';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DraculaTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Download from YouTube',
        style: TextStyle(
          color: DraculaTheme.foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL Input
            TextField(
              controller: _urlController,
              enabled: !_isDownloaded, // Disable input after download
              style: TextStyle(
                color: _isDownloaded ? DraculaTheme.comment : DraculaTheme.foreground,
              ),
              decoration: InputDecoration(
                hintText: _isDownloaded ? 'Download completed' : 'Paste YouTube URL here...',
                hintStyle: TextStyle(
                  color: _isDownloaded ? DraculaTheme.green : DraculaTheme.comment,
                ),
                filled: true,
                fillColor: _isDownloaded 
                  ? DraculaTheme.green.withValues(alpha: 0.1)
                  : DraculaTheme.currentLine,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _isDownloaded ? DraculaTheme.green : Colors.transparent,
                    width: _isDownloaded ? 2 : 0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _isDownloaded ? DraculaTheme.green : Colors.transparent,
                    width: _isDownloaded ? 2 : 0,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: DraculaTheme.green.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(
                  _isDownloaded ? Icons.check_circle : Icons.link,
                  color: _isDownloaded ? DraculaTheme.green : DraculaTheme.purple,
                ),
                suffixIcon: _isDownloaded 
                  ? Icon(Icons.download_done, color: DraculaTheme.green)
                  : null,
              ),
              onSubmitted: _isDownloaded ? null : (_) => _getVideoInfo(),
            ),
            
            const SizedBox(height: 16),
            
            // Get Info Button
            if (!_isDownloaded)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _getVideoInfo,
                  icon: _isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DraculaTheme.background,
                        ),
                      )
                    : Icon(Icons.info_outline),
                  label: Text(_isLoading ? 'Getting info...' : 'Get Video Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DraculaTheme.purple,
                    foregroundColor: DraculaTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DraculaTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DraculaTheme.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: DraculaTheme.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: DraculaTheme.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Video Info Preview
            if (_videoInfo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DraculaTheme.currentLine.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DraculaTheme.purple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _videoInfo!.title,
                      style: TextStyle(
                        color: DraculaTheme.foreground,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _videoInfo!.author,
                      style: TextStyle(
                        color: DraculaTheme.purple,
                        fontSize: 14,
                      ),
                    ),
                    if (_videoInfo!.duration != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${_formatDuration(_videoInfo!.duration!)}',
                        style: TextStyle(
                          color: DraculaTheme.comment,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Download Buttons
              if (!_isDownloaded) ...[
                // Regular Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadAudio,
                    icon: _isDownloading 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DraculaTheme.background,
                          ),
                        )
                      : Icon(Icons.download),
                    label: Text(_isDownloading ? 'Downloading...' : 'Download Audio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DraculaTheme.green,
                      foregroundColor: DraculaTheme.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Background Download Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : () {
                      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
                      
                      // Start background download
                      musicProvider.downloadManager.startDownload(
                        url: _urlController.text.trim(),
                        title: _videoInfo!.title,
                        artist: _videoInfo!.author,
                        thumbnailUrl: null,
                      );
                      
                      Navigator.of(context).pop();
                      
                      // Show toast that download started
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Download started in background: ${_videoInfo!.title}',
                            style: TextStyle(color: DraculaTheme.background),
                          ),
                          backgroundColor: DraculaTheme.cyan,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: Icon(Icons.cloud_download),
                    label: Text('Download in Background'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DraculaTheme.cyan,
                      side: BorderSide(color: DraculaTheme.cyan),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Downloaded status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DraculaTheme.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DraculaTheme.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: DraculaTheme.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Download completed successfully!',
                          style: TextStyle(
                            color: DraculaTheme.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Download Progress
              if (_isDownloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: DraculaTheme.currentLine,
                  valueColor: AlwaysStoppedAnimation<Color>(DraculaTheme.green),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: DraculaTheme.comment,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (_isDownloading && !_isDownloaded) ...[
          // Cancel download button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Download continuing in background...',
                    style: TextStyle(color: DraculaTheme.background),
                  ),
                  backgroundColor: DraculaTheme.cyan,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: Text(
              'Continue in Background',
              style: TextStyle(color: DraculaTheme.cyan),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _isDownloaded ? 'Close' : 'Cancel',
              style: TextStyle(color: DraculaTheme.comment),
            ),
          ),
        ],
        if (_isDownloaded) ...[
          TextButton(
            onPressed: () {
              // Reset for new download
              setState(() {
                _isDownloaded = false;
                _videoInfo = null;
                _urlController.clear();
                _errorMessage = null;
              });
            },
            child: Text(
              'Download Another',
              style: TextStyle(color: DraculaTheme.purple),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
