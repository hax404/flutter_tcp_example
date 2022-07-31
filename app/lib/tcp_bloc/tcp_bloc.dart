import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/message.dart';

part 'tcp_event.dart';
part 'tcp_state.dart';

class TcpBloc extends Bloc<TcpEvent, TcpState> {
  Socket? _socket;
  StreamSubscription? _socketStreamSub;
  ConnectionTask<Socket>? _socketConnectionTask;

  @override
  TcpBloc() : super(TcpState.initial()) {
    on<Connect>((event, emit) async {
      emit(state.copywith(connectionState: SocketConnectionState.Connecting));
      try {
        _socketConnectionTask = await Socket.startConnect(event.host, event.port);
        _socket = await _socketConnectionTask!.socket;

        _socketStreamSub = _socket!.asBroadcastStream().listen((event) {
          this.add(
            MessageReceived(
                message: Message(
                  message: String.fromCharCodes(event),
                  timestamp: DateTime.now(),
                  sender: Sender.Server,
              )
            )
          );
        });
        _socket!.handleError(() {
          this.add(ErrorOccured());
        });
        emit(state.copywith(connectionState: SocketConnectionState.Connected));
      } catch (err) {
        emit(state.copywith(connectionState: SocketConnectionState.Failed));
      }
    });

    on<Disconnect>((event, emit) async {
      try {
        emit(state.copywith(connectionState: SocketConnectionState.Disconnecting));
        _socketConnectionTask?.cancel();
        await _socketStreamSub?.cancel();
        await _socket?.close();
      } catch (ex) {
        print(ex);
      }
      emit(state.copywith(connectionState: SocketConnectionState.None, messages: []));
    });

    on<ErrorOccured>((event, emit) async {
      emit(state.copywith(connectionState: SocketConnectionState.Failed));
      await _socketStreamSub?.cancel();
      await _socket?.close();
    });

    on<SendMessage>((event, emit) async {
      if(_socket != null) {
        emit(state.copyWithNewMessage(message: Message(
          message: event.message,
          timestamp: DateTime.now(),
          sender: Sender.Client,
        )));
        _socket!.writeln(event.message);
      }
    });

    on<MessageReceived>((event, emit) async {
      emit(state.copyWithNewMessage(message: event.message));
    });
  }

  @override
  Future<void> close() {
    _socketStreamSub?.cancel();
    _socket?.close();
    return super.close();
  }
}
