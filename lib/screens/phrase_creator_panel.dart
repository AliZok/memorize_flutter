import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/app_provider.dart';
import '../models/category.dart';

class PhraseCreatorPanel extends StatefulWidget {
  const PhraseCreatorPanel({Key? key}) : super(key: key);

  @override
  State<PhraseCreatorPanel> createState() => _PhraseCreatorPanelState();
}

class _PhraseCreatorPanelState extends State<PhraseCreatorPanel> {
  final TextEditingController _phraseController = TextEditingController();
  int _mainCategoryId = 1; // 1 = Phrase, 2 = Sentence
  Category? _selectedCategory;

  File? _selectedImage;
  File? _recordedVoice;
  File? _recordedVoiceSecond;

  // Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingV1 = false;
  bool _isRecordingV2 = false;

  // Preview Players
  final AudioPlayer _previewPlayerV1 = AudioPlayer();
  final AudioPlayer _previewPlayerV2 = AudioPlayer();
  bool _isPlayingPreviewV1 = false;
  bool _isPlayingPreviewV2 = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _previewPlayerV1.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingPreviewV1 = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });
    _previewPlayerV2.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingPreviewV2 = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });
  }

  @override
  void dispose() {
    _phraseController.dispose();
    _audioRecorder.dispose();
    _previewPlayerV1.dispose();
    _previewPlayerV2.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // --- RECORDING LOGIC ---

  Future<void> _startRecording(bool isV1) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${tempDir.path}/rec_${isV1 ? "v1" : "v2"}_$timestamp.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: path,
        );

        setState(() {
          if (isV1) {
          _isRecordingV1 = true;
        } else {
          _isRecordingV2 = true;
        }
      });
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording(bool isV1) async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        if (isV1) {
          _isRecordingV1 = false;
          if (path != null) _recordedVoice = File(path);
        } else {
          _isRecordingV2 = false;
          if (path != null) _recordedVoiceSecond = File(path);
        }
      });

      // Prepare preview player
      if (path != null) {
        if (isV1) {
          await _previewPlayerV1.setFilePath(path);
        } else {
          await _previewPlayerV2.setFilePath(path);
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _togglePlayPreview(bool isV1) async {
    final player = isV1 ? _previewPlayerV1 : _previewPlayerV2;
    final isPlaying = isV1 ? _isPlayingPreviewV1 : _isPlayingPreviewV2;

    if (isPlaying) {
      await player.pause();
    } else {
      await player.seek(Duration.zero);
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFCFFFEB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Sliding Handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Phrase',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B307B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Form Scrollable Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // 1. Phrase/Sentence Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Phrase',
                            style: TextStyle(
                              color: _mainCategoryId == 1 ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: _mainCategoryId == 1,
                          selectedColor: const Color(0xFF0B307B),
                          onSelected: (selected) {
                            if (selected) setState(() => _mainCategoryId = 1);
                          },
                        ),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: Text(
                            'Sentence',
                            style: TextStyle(
                              color: _mainCategoryId == 2 ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: _mainCategoryId == 2,
                          selectedColor: const Color(0xFF0B307B),
                          onSelected: (selected) {
                            if (selected) setState(() => _mainCategoryId = 2);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Phrase Text Input
                    TextField(
                      controller: _phraseController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _mainCategoryId == 1 ? 'Phrase Text' : 'Sentence Text',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Category Dropdown
                    DropdownButtonFormField<Category>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Select Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      items: provider.categories.map<DropdownMenuItem<Category>>((Category cat) {
                        return DropdownMenuItem<Category>(
                          value: cat,
                          child: Text(cat.title),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // 4. Image Picker Preview
                    const Text('Phrase Image (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[300]!),
                            image: _selectedImage != null
                                ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _selectedImage == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Tap to select or take a photo', style: TextStyle(color: Colors.grey)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Voice Recorder 1 (Main Voice)
                    _buildRecorderSection(
                      title: 'Main Voice (V1)',
                      isRecording: _isRecordingV1,
                      recordedFile: _recordedVoice,
                      isPlayingPreview: _isPlayingPreviewV1,
                      onRecordToggle: () {
                        if (_isRecordingV1) {
                          _stopRecording(true);
                        } else {
                          _startRecording(true);
                        }
                      },
                      onPlayPreview: () => _togglePlayPreview(true),
                    ),
                    const SizedBox(height: 16),

                    // 6. Voice Recorder 2 (Translated Voice)
                    _buildRecorderSection(
                      title: 'Translated Voice (V2 - Optional)',
                      isRecording: _isRecordingV2,
                      recordedFile: _recordedVoiceSecond,
                      isPlayingPreview: _isPlayingPreviewV2,
                      onRecordToggle: () {
                        if (_isRecordingV2) {
                          _stopRecording(false);
                        } else {
                          _startRecording(false);
                        }
                      },
                      onPlayPreview: () => _togglePlayPreview(false),
                    ),
                    const SizedBox(height: 32),

                    // 7. Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: provider.isBusy
                            ? null
                            : () async {
                                final text = _phraseController.text.trim();
                                if (text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter phrase text')),
                                  );
                                  return;
                                }

                                await provider.createNewPhrase(
                                  phraseText: text,
                                  mainCategoryId: _mainCategoryId,
                                  categoryId: _selectedCategory?.id,
                                  imageFile: _selectedImage,
                                  voiceFile: _recordedVoice,
                                  voiceSecondFile: _recordedVoiceSecond,
                                );

                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B307B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: provider.isBusy
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Save Phrase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecorderSection({
    required String title,
    required bool isRecording,
    required File? recordedFile,
    required bool isPlayingPreview,
    required VoidCallback onRecordToggle,
    required VoidCallback onPlayPreview,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // Record Button
              GestureDetector(
                onTap: onRecordToggle,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.redAccent : Colors.indigo[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRecording ? Icons.stop : Icons.mic,
                    color: isRecording ? Colors.white : const Color(0xFF0B307B),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecording
                          ? 'Recording...'
                          : (recordedFile != null ? 'Voice Recorded' : 'No Voice Recorded'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRecording ? Colors.redAccent : Colors.black87,
                      ),
                    ),
                    if (isRecording)
                      const Text('Tap stop button to finish', style: TextStyle(color: Colors.grey, fontSize: 12))
                    else if (recordedFile != null)
                      const Text('You can preview or record again', style: TextStyle(color: Colors.grey, fontSize: 12))
                    else
                      const Text('Tap mic to start recording', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              // Playback Preview Button (only if recorded)
              if (recordedFile != null && !isRecording)
                IconButton(
                  icon: Icon(isPlayingPreview ? Icons.pause_circle : Icons.play_circle, size: 36, color: Colors.green),
                  onPressed: onPlayPreview,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

