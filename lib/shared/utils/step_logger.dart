import 'dart:developer' as developer;

class StepLogger {
  const StepLogger(this.scope);

  final String scope;

  void info(String message) {
    developer.log(message, name: scope);
  }
}
