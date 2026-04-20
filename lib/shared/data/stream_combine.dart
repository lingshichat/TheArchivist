import 'dart:async';

Stream<R> combineLatest4<A, B, C, D, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  R Function(A a, B b, C c, D d) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subscriptionA;
  StreamSubscription<B>? subscriptionB;
  StreamSubscription<C>? subscriptionC;
  StreamSubscription<D>? subscriptionD;

  A? latestA;
  B? latestB;
  C? latestC;
  D? latestD;
  bool hasA = false;
  bool hasB = false;
  bool hasC = false;
  bool hasD = false;

  void emitIfReady() {
    if (!hasA || !hasB || !hasC || !hasD) {
      return;
    }

    controller.add(
      combine(latestA as A, latestB as B, latestC as C, latestD as D),
    );
  }

  controller = StreamController<R>(
    onListen: () {
      subscriptionA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emitIfReady();
      }, onError: controller.addError);
      subscriptionB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emitIfReady();
      }, onError: controller.addError);
      subscriptionC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emitIfReady();
      }, onError: controller.addError);
      subscriptionD = streamD.listen((value) {
        latestD = value;
        hasD = true;
        emitIfReady();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subscriptionA?.cancel();
      await subscriptionB?.cancel();
      await subscriptionC?.cancel();
      await subscriptionD?.cancel();
    },
  );

  return controller.stream;
}
