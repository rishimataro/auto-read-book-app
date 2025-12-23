import 'package:flutter_bloc/flutter_bloc.dart';

class CameraCubit extends Cubit<bool> {
  CameraCubit() : super(false);

  void toggleCamera() {
    emit(!state);
  }
}