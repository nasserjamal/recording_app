class AudioFile {
  String filePath;
  bool isUploaded;

  AudioFile({required this.filePath, required this.isUploaded});

  // Convert an AudioFile object to a Map
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'isUploaded': isUploaded,
    };
  }

  // Create an AudioFile object from a Map
  factory AudioFile.fromJson(Map<String, dynamic> json) {
    return AudioFile(
      filePath: json['filePath'],
      isUploaded: json['isUploaded'],
    );
  }
}
