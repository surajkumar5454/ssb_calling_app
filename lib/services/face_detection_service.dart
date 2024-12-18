import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FaceDetectionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  Future<List<Face>> detectFaces(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  Future<double> compareFaces(String image1Path, String image2Path) async {
    try {
      // Load and detect faces in both images
      final faces1 = await detectFaces(image1Path);
      final faces2 = await detectFaces(image2Path);

      if (faces1.isEmpty || faces2.isEmpty) {
        return 0.0;
      }

      // Get the first face from each image
      final face1 = faces1.first;
      final face2 = faces2.first;

      // Compare facial features
      double similarity = _compareFacialFeatures(face1, face2);
      return similarity;
    } catch (e) {
      print('Error comparing faces: $e');
      return 0.0;
    }
  }

  double _compareFacialFeatures(Face face1, Face face2) {
    double similarity = 0.0;
    int comparedFeatures = 0;

    // Compare face rotation
    if (face1.headEulerAngleY != null && face2.headEulerAngleY != null) {
      double angleDiff = (face1.headEulerAngleY! - face2.headEulerAngleY!).abs();
      similarity += 1.0 - (angleDiff / 90.0); // Normalize to 0-1
      comparedFeatures++;
    }

    // Compare smile probability
    if (face1.smilingProbability != null && face2.smilingProbability != null) {
      double smileDiff = (face1.smilingProbability! - face2.smilingProbability!).abs();
      similarity += 1.0 - smileDiff;
      comparedFeatures++;
    }

    // Compare left eye open probability
    if (face1.leftEyeOpenProbability != null && face2.leftEyeOpenProbability != null) {
      double leftEyeDiff = (face1.leftEyeOpenProbability! - face2.leftEyeOpenProbability!).abs();
      similarity += 1.0 - leftEyeDiff;
      comparedFeatures++;
    }

    // Compare right eye open probability
    if (face1.rightEyeOpenProbability != null && face2.rightEyeOpenProbability != null) {
      double rightEyeDiff = (face1.rightEyeOpenProbability! - face2.rightEyeOpenProbability!).abs();
      similarity += 1.0 - rightEyeDiff;
      comparedFeatures++;
    }

    // Return average similarity
    return comparedFeatures > 0 ? similarity / comparedFeatures : 0.0;
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
