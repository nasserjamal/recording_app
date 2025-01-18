class Longprocess {
  // Private constructor
  Longprocess._privateConstructor();

  // Singleton instance
  static final Longprocess _instance = Longprocess._privateConstructor();

  // Factory constructor to return the singleton instance
  factory Longprocess() {
    return _instance;
  }

  int _counter = 0;

  int get counter => _counter;

  Future<void> startCounter() async {
    for (var i = 0; i < 1000000000; i++) {
      _counter = i;
      print('Counter: $i');
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // Add your methods and properties here
}
