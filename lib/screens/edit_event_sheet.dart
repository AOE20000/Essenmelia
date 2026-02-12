import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/tags_provider.dart';
import '../widgets/tag_input.dart';
import '../widgets/universal_image.dart';
import '../providers/ui_state_provider.dart';
import '../features/quick_action/ocr_service.dart';
import '../features/quick_action/contour_service.dart';

class EditEventSheet extends ConsumerStatefulWidget {
  final Event? event;
  final bool isSidePanel;
  const EditEventSheet({super.key, this.event, this.isSidePanel = false});

  @override
  ConsumerState<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends ConsumerState<EditEventSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  String? _currentImageUrl;
  List<String> _selectedTags = [];
  List<String> _recommendedTags = [];
  bool _isSaving = false;

  // ML 状态
  final OcrService _ocrService = OcrService();
  final ContourService _contourService = ContourService();
  bool _isProcessingML = false;
  List<String> _croppedImagePaths = [];
  String? _recognizedText;
  bool _wasAutoFilled = false; // 新增：标记是否发生了自动填充

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _currentImageUrl = widget.event?.imageUrl;
    _selectedTags = widget.event?.tags ?? [];

    _titleController.addListener(_updateRecommendations);
    _descController.addListener(_updateRecommendations);

    // 初始推荐
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateRecommendations(),
    );
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateRecommendations);
    _descController.removeListener(_updateRecommendations);
    _titleController.dispose();
    _descController.dispose();
    _ocrService.dispose();
    _contourService.dispose();
    super.dispose();
  }

  void _updateRecommendations() {
    final title = _titleController.text.toLowerCase();
    final desc = _descController.text.toLowerCase();
    final ocr = (_recognizedText ?? '').toLowerCase();
    final combined = '$title $desc $ocr';

    if (combined.trim().isEmpty) {
      if (_recommendedTags.isNotEmpty) {
        setState(() => _recommendedTags = []);
      }
      return;
    }

    final allTags = ref.read(tagsProvider).value ?? [];
    final recommendations = allTags.where((tag) {
      return combined.contains(tag.toLowerCase()) &&
          !_selectedTags.contains(tag);
    }).toList();

    if (recommendations.length != _recommendedTags.length ||
        !recommendations.every((t) => _recommendedTags.contains(t))) {
      setState(() => _recommendedTags = recommendations);
    }
  }

  void _clearImage() {
    setState(() {
      _currentImageUrl = null;
    });
  }

  Future<void> _handleImageFile(File file) async {
    try {
      setState(() {
        _isProcessingML = true;
        _croppedImagePaths = [];
      });

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path)}';
      final savedPath = p.join(imagesDir.path, fileName);

      await file.copy(savedPath);

      setState(() {
        _currentImageUrl = savedPath;
      });

      // 默认不再启动 ML 处理，由用户手动点击触发
    } catch (e) {
      debugPrint('Error handling image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理图片失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingML = false);
    }
  }

  Future<void> _processImageML(File imageFile) async {
    setState(() => _isProcessingML = true);
    try {
      // 1. OCR 识别
      final textResult = await _ocrService.recognizeDetailed(imageFile.path);
      final blocks = textResult['blocks'] as List<Map<String, dynamic>>;

      // 2. 物体检测与裁切
      final objectsResult = await _contourService.detectObjects(imageFile.path);
      final List<String> croppedPaths = [];

      final bytes = await imageFile.readAsBytes();
      img.Image? baseImage = img.decodeImage(bytes);

      if (baseImage != null) {
        baseImage = img.bakeOrientation(baseImage);
        final tempDir = await getTemporaryDirectory();
        final objects = objectsResult['objects'] as List<Map<String, dynamic>>;

        for (int i = 0; i < objects.length; i++) {
          final rect = objects[i]['rect'];
          final left = rect['left'].toInt().clamp(0, baseImage.width - 1);
          final top = rect['top'].toInt().clamp(0, baseImage.height - 1);
          final right = rect['right'].toInt().clamp(1, baseImage.width);
          final bottom = rect['bottom'].toInt().clamp(1, baseImage.height);

          int width = right - left;
          int height = bottom - top;

          if (width > 50 && height > 50) {
            final cropped = img.copyCrop(
              baseImage,
              x: left,
              y: top,
              width: width,
              height: height,
            );

            final croppedFile = File(
              p.join(
                tempDir.path,
                'crop_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
              ),
            );
            await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 85));
            croppedPaths.add(croppedFile.path);
          }
        }
      }

      if (mounted) {
        setState(() {
          _recognizedText = textResult['fullText'] as String;
          _croppedImagePaths = croppedPaths;
          // 重新计算标签推荐
          _updateRecommendations();
        });

        // 所有分析完成后再显示选择器，确保数据完整
        if (blocks.isNotEmpty || croppedPaths.isNotEmpty) {
          _showOcrResultPicker(imageFile, blocks);
        }
      }
    } catch (e) {
      debugPrint('ML Processing error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingML = false);
    }
  }

  void _showOcrResultPicker(
    File originalFile,
    List<Map<String, dynamic>> blocks,
  ) {
    final theme = Theme.of(context);

    // 本地暂存状态
    String tempImageUrl = _currentImageUrl ?? originalFile.path;
    String tempTitle = _titleController.text;
    String tempDescription = _descController.text;
    final List<int> selectedBlockIndices = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部栏
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      '智能分析选择',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 精彩画面 (物体识别结果)
                      Row(
                        children: [
                          Text(
                            '精彩画面',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'AI 裁切',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 使用成员变量确保实时刷新
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // 原图选项
                            _buildPickerImageItem(
                              theme,
                              originalFile.path,
                              '完整原图',
                              tempImageUrl,
                              (path) =>
                                  setModalState(() => tempImageUrl = path),
                            ),
                            const SizedBox(width: 12),
                            // 识别出的物体
                            ..._croppedImagePaths.map(
                              (path) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildPickerImageItem(
                                  theme,
                                  path,
                                  null,
                                  tempImageUrl,
                                  (path) =>
                                      setModalState(() => tempImageUrl = path),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 文字选择
                      Text(
                        '文字识别结果',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击选择：第1次点击设为标题，后续点击追加到描述',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(blocks.length, (index) {
                          final isSelected = selectedBlockIndices.contains(
                            index,
                          );
                          return FilterChip(
                            label: Text(
                              (blocks[index]['text'] as String)
                                  .replaceAll('\n', ' ')
                                  .trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  selectedBlockIndices.add(index);
                                } else {
                                  selectedBlockIndices.remove(index);
                                }

                                // 重新计算预览内容
                                if (selectedBlockIndices.isEmpty) {
                                  tempTitle = '';
                                  tempDescription = '';
                                } else {
                                  final firstIndex = selectedBlockIndices.first;
                                  tempTitle =
                                      (blocks[firstIndex]['text'] as String)
                                          .replaceAll('\n', ' ')
                                          .trim();

                                  if (selectedBlockIndices.length > 1) {
                                    tempDescription = selectedBlockIndices
                                        .skip(1)
                                        .map(
                                          (idx) =>
                                              (blocks[idx]['text'] as String)
                                                  .replaceAll('\n', ' ')
                                                  .trim(),
                                        )
                                        .join('\n');
                                  } else {
                                    tempDescription = '';
                                  }
                                }
                              });
                            },
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            selectedColor: theme.colorScheme.primaryContainer,
                            checkmarkColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (selectedBlockIndices.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              tempTitle = '';
                              tempDescription = '';
                              selectedBlockIndices.clear();
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('重置文字选择'),
                        ),
                      const SizedBox(height: 24),

                      // 预览区域
                      if (tempTitle.isNotEmpty ||
                          tempDescription.isNotEmpty) ...[
                        Text(
                          '应用预览',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tempTitle.isNotEmpty) ...[
                                Text(
                                  tempTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (tempDescription.isNotEmpty)
                                  const SizedBox(height: 8),
                              ],
                              if (tempDescription.isNotEmpty)
                                Text(
                                  tempDescription,
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 底部操作栏
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _currentImageUrl = tempImageUrl;
                            _titleController.text = tempTitle;
                            _descController.text = tempDescription;
                            _wasAutoFilled = true;
                          });
                          Navigator.pop(context);
                          _clearAutoFillFlag();
                        },
                        child: const Text('确认应用'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerImageItem(
    ThemeData theme,
    String path,
    String? label,
    String currentPath,
    Function(String) onSelect,
  ) {
    final isSelected = currentPath == path;
    return GestureDetector(
      onTap: () => onSelect(path),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 220,
                ),
              ),
            ),
            if (label != null)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _clearAutoFillFlag() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _wasAutoFilled = false);
    });
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (details.files.isNotEmpty) {
      final firstFile = details.files.first;
      final ext = p.extension(firstFile.path).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
        await _handleImageFile(File(firstFile.path));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('不支持的文件格式')));
        }
      }
    }
  }

  Future<void> _pasteImage() async {
    debugPrint('开始从剪贴板粘贴...');
    try {
      // 1. 尝试获取图片字节 (部分平台如 Android 0.3.0 可能未实现此方法)
      try {
        final bytes = await Pasteboard.image;
        if (bytes != null) {
          debugPrint('获取到图片字节: ${bytes.length}');
          final tempDir = await getTemporaryDirectory();
          final file = File(
            p.join(
              tempDir.path,
              'pasted_${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          );
          await file.writeAsBytes(bytes);
          await _handleImageFile(file);
          return;
        }
      } catch (e) {
        debugPrint('获取图片字节失败 (可能平台不支持): $e');
      }

      // 2. 尝试获取文件路径
      try {
        final files = await Pasteboard.files();
        if (files.isNotEmpty) {
          debugPrint('获取到剪贴板文件: $files');
          final firstFile = files.first;
          final ext = p.extension(firstFile).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
            await _handleImageFile(File(firstFile));
            return;
          }
        }
      } catch (e) {
        debugPrint('获取剪贴板文件失败: $e');
      }

      // 3. 尝试获取文本 (可能是图片 URL)
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      if (text != null && text.isNotEmpty) {
        debugPrint('获取到剪贴板文本: $text');
        if (text.startsWith('http') &&
            (text.toLowerCase().contains('.jpg') ||
                text.toLowerCase().contains('.jpeg') ||
                text.toLowerCase().contains('.png') ||
                text.toLowerCase().contains('.webp'))) {
          // 这是一个图片 URL，尝试下载
          await _downloadAndHandleImage(text);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('剪贴板中没有识别到图片或有效链接')));
      }
    } catch (e) {
      debugPrint('粘贴流程发生异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('粘贴失败: $e')));
      }
    }
  }

  Future<void> _downloadAndHandleImage(String url) async {
    try {
      setState(() => _isSaving = true);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          p.join(
            tempDir.path,
            'downloaded_${DateTime.now().millisecondsSinceEpoch}${p.extension(url).isEmpty ? '.jpg' : p.extension(url)}',
          ),
        );
        await file.writeAsBytes(response.bodyBytes);
        await _handleImageFile(file);
      } else {
        throw '下载失败 (${response.statusCode})';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法从链接获取图片: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportImage() async {
    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) return;

    try {
      final file = File(_currentImageUrl!);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(file.path)], text: '导出图片');
      } else {
        throw '文件不存在';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        await _handleImageFile(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPickImage(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('从剪贴板粘贴'),
              onTap: () {
                Navigator.pop(context);
                _pasteImage();
              },
            ),
            if (_currentImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('清除图片', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _clearImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContentInsertion(KeyboardInsertedContent content) async {
    debugPrint('接收到输入法内容插入: ${content.mimeType}');
    if (content.data != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          p.join(
            tempDir.path,
            'ime_inserted_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
        );
        await file.writeAsBytes(content.data!);
        await _handleImageFile(file);
      } catch (e) {
        debugPrint('处理输入法插入内容失败: $e');
      }
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      // 在保存前，将所有新标签同步到全局库
      for (final tag in _selectedTags) {
        ref.read(tagsProvider.notifier).addTag(tag);
      }

      if (widget.event != null) {
        final event = widget.event!;
        event.title = title;
        event.description = _descController.text.trim();
        event.imageUrl = _currentImageUrl;
        event.tags = _selectedTags;
        await event.save();
      } else {
        await ref
            .read(eventsProvider.notifier)
            .addEvent(
              title: title,
              description: _descController.text.trim(),
              imageUrl: _currentImageUrl,
              tags: _selectedTags,
            );
      }

      if (mounted) {
        if (widget.isSidePanel) {
          ref.read(leftPanelContentProvider.notifier).state =
              LeftPanelContent.none;
        } else {
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片区域
          GestureDetector(
            onTap: _showImageOptions,
            onLongPress: _currentImageUrl != null ? _exportImage : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: _currentImageUrl != null
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_currentImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          UniversalImage(
                            imageUrl: _currentImageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.2),
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.4),
                                  ],
                                  stops: const [0.0, 0.2, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '添加一张有故事的图片',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '支持拖放、粘贴或相册选择',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isProcessingML)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '正在智能解析内容...',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_currentImageUrl != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton.filledTonal(
                        onPressed: _clearImage,
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        if (_currentImageUrl != null) ...[
                          _ImageActionButton(
                            icon: Icons.auto_awesome,
                            onPressed: () =>
                                _processImageML(File(_currentImageUrl!)),
                            tooltip: '智能解析内容',
                          ),
                          const SizedBox(width: 8),
                          _ImageActionButton(
                            icon: Icons.ios_share,
                            onPressed: _exportImage,
                            tooltip: '导出原图',
                          ),
                        ],
                        const SizedBox(width: 8),
                        _ImageActionButton(
                          icon: Icons.content_paste,
                          onPressed: _pasteImage,
                          tooltip: '从剪贴板粘贴',
                        ),
                        const SizedBox(width: 8),
                        _ImageActionButton(
                          icon: Icons.photo_library,
                          onPressed: _pickImage,
                          tooltip: '选择图片',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 标题输入框
          TextField(
            controller: _titleController,
            contentInsertionConfiguration: ContentInsertionConfiguration(
              onContentInserted: _handleContentInsertion,
              allowedMimeTypes: const [
                'image/png',
                'image/jpeg',
                'image/gif',
                'image/webp',
              ],
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: '给事件起个标题...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              suffixIcon: _wasAutoFilled
                  ? Tooltip(
                      message: '由智能助手自动填充',
                      child: Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),
          Divider(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),

          // 描述输入框
          TextField(
            controller: _descController,
            maxLines: null,
            contentInsertionConfiguration: ContentInsertionConfiguration(
              onContentInserted: _handleContentInsertion,
              allowedMimeTypes: const [
                'image/png',
                'image/jpeg',
                'image/gif',
                'image/webp',
              ],
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '记录这一刻的详细内容...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 32),

          // 标签
          Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '标签',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TagInput(
            initialTags: _selectedTags,
            recommendedTags: _recommendedTags,
            onChanged: (tags) {
              setState(() => _selectedTags = tags);
              _updateRecommendations();
            },
          ),
          const SizedBox(height: 120), // 为悬浮按钮留出空间
        ],
      ),
    );

    final body = DropTarget(
      onDragDone: _handleDrop,
      child: Stack(
        children: [
          bodyContent,
          // 底部悬浮按钮 (仅在移动端或非桌面端正常显示时显示)
          if (!isDesktop || widget.isSidePanel)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: SafeArea(
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: theme.colorScheme.shadow.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(widget.event == null ? Icons.add : Icons.check),
                      const SizedBox(width: 12),
                      Text(
                        widget.event == null ? '创建记录' : '保存修改',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.isSidePanel) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.event == null
                ? AppLocalizations.of(context)!.newEvent
                : AppLocalizations.of(context)!.editEvent,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(leftPanelContentProvider.notifier).state =
                LeftPanelContent.none,
          ),
          actions: [
            if (!_isSaving)
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
          ],
        ),
        body: body,
      );
    }

    if (isDesktop) {
      // 桌面端作为对话框或固定面板展示
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 拖动手柄
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 顶部栏
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      widget.event == null
                          ? AppLocalizations.of(context)!.newEvent
                          : AppLocalizations.of(context)!.editEvent,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(widget.event == null ? '创建' : '保存'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    // 移动端普通底部面板
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null
              ? AppLocalizations.of(context)!.newEvent
              : AppLocalizations.of(context)!.editEvent,
        ),
        actions: [
          if (!_isSaving)
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: body,
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ImageActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
