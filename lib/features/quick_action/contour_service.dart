import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ContourService {
  late ObjectDetector _objectDetector;

  ContourService() {
    // 使用基础模型进行通用物体检测
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  Future<Map<String, dynamic>> detectObjects(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<DetectedObject> objects = await _objectDetector.processImage(
      inputImage,
    );

    final List<Map<String, dynamic>> result = objects
        .map(
          (obj) => {
            'rect': {
              'left': obj.boundingBox.left,
              'top': obj.boundingBox.top,
              'right': obj.boundingBox.right,
              'bottom': obj.boundingBox.bottom,
            },
            'labels': obj.labels.map((l) => l.text).toList(),
          },
        )
        .toList();

    return {'objects': result};
  }

  void dispose() {
    _objectDetector.close();
  }
}
