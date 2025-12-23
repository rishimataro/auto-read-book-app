import 'package:demo/data/repositories/pi_repository.dart';
import 'package:demo/logic/connection/connection_cubit.dart';
import 'package:demo/logic/connection/connection_state.dart';
import 'package:demo/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectionCubit(PiRepository()),
      child: const ConnectionPage(),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  @override
  void initState() {
    super.initState();
    context.read<ConnectionCubit>().findDevice();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BlocConsumer<ConnectionCubit, ConnectionState>(
          listener: (context, state) {
            if (state is ConnectionSuccess) {
              context.read<ConnectionCubit>().connect(state.ip);
            }
            if (state is ConnectionEstablished) {
              // Pass ConnectionCubit to HomeScreen
              final connectionCubit = context.read<ConnectionCubit>();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: connectionCubit,
                    child: const HomeScreen(),
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ConnectionScanning) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Đang quét tìm thiết bị..."),
                ],
              );
            } else if (state is ConnectionConnecting) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Đang kết nối tới thiết bị..."),
                ],
              );
            } else if (state is ConnectionFailure || state is ConnectionError) {
              String message;
              if (state is ConnectionFailure) {
                message = state.message;
              } else {
                message = (state as ConnectionError).message;
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ConnectionCubit>().findDevice(),
                    child: const Text("Thử lại"),
                  )
                ],
              );
            }
            return Container();
          },
        ),
      ),
    );
  }
}
