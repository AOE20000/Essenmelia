import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'ocr_service.dart';
import 'contour_service.dart';
import '../../providers/events_provider.dart';

class QuickActionScreen extends ConsumerStatefulWidget {
  const QuickActionScreen({super.key});

  @override
  ConsumerState<QuickActionScreen> createState() => _QuickActionScreenState();
}

class _QuickActionScreenState extends ConsumerState<QuickActionScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final ContourService _contourService = ContourService();

  File? _imageFile;
  String _recognizedText = '';
  bool _isProcessing = false;
  List<Map<String, dynamic>> _detectedObjects = [];
  List<Map<String, dynamic>> _textBlocks = [];
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    // 不再自动调用 _pickImage，由 UI 引导用户操作
  }

  Future<void> _pasteImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(bytes);
        await _handleImageFile(file);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('剪贴板中没有图片')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('粘贴失败: $e')));
      }
    }
  }

  Future<void> _handleImageFile(File file) async {
    final decodedImage = await decodeImageFromList(await file.readAsBytes());
    setState(() {
      _imageFile = file;
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      _isProcessing = true;
    });
    await _processImage();
  }

  Future<void> _pickImageSource(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      await _handleImageFile(File(image.path));
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _contourService.dispose();
    super.dispose();
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片来源'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('相机'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('相册'),
          ),
        ],
      ),
    );

    if (source == null) {
      if (mounted && _imageFile == null) Navigator.of(context).pop();
      return;
    }

    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      final file = File(image.path);
      // 获取图片尺寸用于坐标转换
      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      setState(() {
        _imageFile = file;
        _imageSize = Size(
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        );
        _isProcessing = true;
      });
      await _processImage();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onImageTap(Offset localOffset, BoxConstraints constraints) {
    if (_imageSize == null) return;

    // 计算缩放比例和偏移量（逻辑与 Painter 一致）
    final double containerAspect = constraints.maxWidth / constraints.maxHeight;
    final double imageAspect = _imageSize!.width / _imageSize!.height;

    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspect > containerAspect) {
      scale = constraints.maxWidth / _imageSize!.width;
      offsetY = (constraints.maxHeight - _imageSize!.height * scale) / 2;
    } else {
      scale = constraints.maxHeight / _imageSize!.height;
      offsetX = (constraints.maxWidth - _imageSize!.width * scale) / 2;
    }

    // 将点击坐标转换为图片坐标
    final double imageX = (localOffset.dx - offsetX) / scale;
    final double imageY = (localOffset.dy - offsetY) / scale;

    // 1. 优先寻找文本块
    for (var block in _textBlocks) {
      final rect = block['rect'];
      if (imageX >= rect['left'] &&
          imageX <= rect['right'] &&
          imageY >= rect['top'] &&
          imageY <= rect['bottom']) {
        setState(() {
          _recognizedText = block['text'];
        });
        return;
      }
    }

    // 2. 其次寻找检测到的物体
    for (var obj in _detectedObjects) {
      final rect = obj['rect'];
      if (imageX >= rect['left'] &&
          imageX <= rect['right'] &&
          imageY >= rect['top'] &&
          imageY <= rect['bottom']) {
        // 如果物体有标签，将其设为标题
        if (obj['labels'].isNotEmpty) {
          setState(() {
            _recognizedText = obj['labels'].first;
          });
        }
        return;
      }
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    try {
      final ocrResult = await _ocrService.recognizeDetailed(_imageFile!.path);
      final contours = await _contourService.detectContours(_imageFile!.path);

      setState(() {
        _recognizedText = ocrResult['fullText'];
        _textBlocks = List<Map<String, dynamic>>.from(ocrResult['blocks']);
        _detectedObjects = contours;
        _isProcessing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('识别失败: $e')));
      }
    }
  }

  Future<void> _cropImage() async {
    if (_imageFile == null || !mounted || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _imageFile!.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '截取图片内容',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: '截取图片内容'),
        ],
      );

      if (croppedFile != null && mounted) {
        final file = File(croppedFile.path);
        final decodedImage = await decodeImageFromList(
          await file.readAsBytes(),
        );
        setState(() {
          _imageFile = file;
          _imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
          _isProcessing = true;
        });
        await _processImage();
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('裁剪出错: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _createEvent() async {
    if (_recognizedText.isEmpty || _imageFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. 将临时图片保存到持久化目录
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}';
      final savedPath = p.join(appDir.path, fileName);
      final savedFile = await _imageFile!.copy(savedPath);

      // 2. 创建事件
      await ref
          .read(eventsProvider.notifier)
          .addEvent(
            title: _recognizedText.split('\n').first,
            description: _recognizedText,
            imageUrl: savedFile.path,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('事件已存入库中')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有选择图片，显示一个“弹出窗口”风格的选择界面
    if (_imageFile == null) {
      return Scaffold(
        backgroundColor: Colors.black54, // 半透明背景
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '快速记录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '粘贴或选择一张图片进行识别',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickActionBtn(
                      icon: Icons.content_paste,
                      label: '粘贴图片',
                      onTap: _pasteImage,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _buildQuickActionBtn(
                      icon: Icons.photo_library,
                      label: '从相册选',
                      onTap: () => _pickImageSource(ImageSource.gallery),
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    _buildQuickActionBtn(
                      icon: Icons.camera_alt,
                      label: '拍照',
                      onTap: () => _pickImageSource(ImageSource.camera),
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('快速识别创建'),
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(Icons.crop),
              onPressed: _cropImage,
              tooltip: '手动截取',
            ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickImage,
            tooltip: '更换图片',
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_imageFile != null && _imageSize != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '点击图片中的物体或文本块可快速聚焦识别:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.file(_imageFile!, fit: BoxFit.contain),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    // 计算缩放比例
                                    double scale = 1.0;
                                    if (_imageSize != null) {
                                      final double containerAspect =
                                          constraints.maxWidth /
                                          constraints.maxHeight;
                                      final double imageAspect =
                                          _imageSize!.width /
                                          _imageSize!.height;

                                      if (imageAspect > containerAspect) {
                                        scale =
                                            constraints.maxWidth /
                                            _imageSize!.width;
                                      } else {
                                        scale =
                                            constraints.maxHeight /
                                            _imageSize!.height;
                                      }
                                    }

                                    return GestureDetector(
                                      onTapUp: (details) {
                                        _onImageTap(
                                          details.localPosition,
                                          constraints,
                                        );
                                      },
                                      child: CustomPaint(
                                        size: Size(
                                          constraints.maxWidth,
                                          constraints.maxHeight,
                                        ),
                                        painter: BoundingBoxPainter(
                                          objects: _detectedObjects,
                                          textBlocks: _textBlocks,
                                          imageSize: _imageSize!,
                                          scale: scale,
                                          colorScheme: Theme.of(
                                            context,
                                          ).colorScheme,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    '识别结果 (第一行将作为标题):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _recognizedText),
                    maxLines: 8,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '正在识别文本...',
                    ),
                    onChanged: (val) => _recognizedText = val,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _recognizedText.isNotEmpty ? _createEvent : null,
                    icon: const Icon(Icons.add_task),
                    label: const Text('存入事件库'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;
  final List<Map<String, dynamic>> textBlocks;
  final Size imageSize;
  final double scale;
  final ColorScheme colorScheme;

  BoundingBoxPainter({
    required this.objects,
    required this.textBlocks,
    required this.imageSize,
    required this.scale,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintObj = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = colorScheme.primary.withOpacity(0.6);

    final paintText = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = colorScheme.secondary.withOpacity(0.4);

    // 居中偏移量
    final double offsetX = (size.width - imageSize.width * scale) / 2;
    final double offsetY = (size.height - imageSize.height * scale) / 2;

    for (var obj in objects) {
      final rect = obj['rect'];
      canvas.drawRect(
        Rect.fromLTRB(
          rect['left'] * scale + offsetX,
          rect['top'] * scale + offsetY,
          rect['right'] * scale + offsetX,
          rect['bottom'] * scale + offsetY,
        ),
        paintObj,
      );
    }

    for (var block in textBlocks) {
      final rect = block['rect'];
      canvas.drawRect(
        Rect.fromLTRB(
          rect['left'] * scale + offsetX,
          rect['top'] * scale + offsetY,
          rect['right'] * scale + offsetX,
          rect['bottom'] * scale + offsetY,
        ),
        paintText,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.textBlocks != textBlocks ||
        oldDelegate.scale != scale;
  }
}
