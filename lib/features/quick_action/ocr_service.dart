import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.chinese,
  );

  Future<Map<String, dynamic>> recognizeDetailed(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    final List<Map<String, dynamic>> blocks = [];
    for (TextBlock block in recognizedText.blocks) {
      blocks.add({
        'text': block.text,
        'rect': {
          'left': block.boundingBox.left,
          'top': block.boundingBox.top,
          'right': block.boundingBox.right,
          'bottom': block.boundingBox.bottom,
        },
      });
    }

    return {'fullText': recognizedText.text, 'blocks': blocks};
  }

  void dispose() {
    _textRecognizer.close();
  }
}
