import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Reads the UID of a physical NFC/contactless card using the Windows
/// smart-card (PC/SC) API via `winscard.dll` and Dart FFI.
///
/// This talks to the same CCID reader Windows already detected. It sends the
/// standard PC/SC "GET DATA" APDU (FF CA 00 00 00) which returns the card's
/// UID for ISO 14443 (MIFARE / NTAG) contactless cards.
///
/// Only Windows is supported here (the salon terminals are Windows). On other
/// platforms [isSupported] is false and calls throw [NfcException].
class NfcException implements Exception {
  const NfcException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when a card scan is cancelled by the user.
class NfcCancelledException implements Exception {
  const NfcCancelledException();
  @override
  String toString() => 'Card scan cancelled.';
}

// ── PC/SC constants (from WinSCard.h) ────────────────────────────────────────
const int _scardScopeUser = 0;
const int _scardShareShared = 2;
const int _scardProtocolT0 = 1;
const int _scardProtocolT1 = 2;
// Dispositions on disconnect.
const int _scardResetCard = 1; // reset the card so it's released for the next tap
const int _scardUnpowerCard = 2;
const int _scardSuccess = 0;

// ── Native function typedefs ─────────────────────────────────────────────────
typedef _EstablishContextC = Int32 Function(
    Uint32 dwScope, Pointer reserved1, Pointer reserved2, Pointer<IntPtr> phContext);
typedef _EstablishContextD = int Function(
    int dwScope, Pointer reserved1, Pointer reserved2, Pointer<IntPtr> phContext);

typedef _ReleaseContextC = Int32 Function(IntPtr hContext);
typedef _ReleaseContextD = int Function(int hContext);

typedef _ListReadersC = Int32 Function(IntPtr hContext, Pointer<Utf16> mszGroups,
    Pointer<Utf16> mszReaders, Pointer<Uint32> pcchReaders);
typedef _ListReadersD = int Function(int hContext, Pointer<Utf16> mszGroups,
    Pointer<Utf16> mszReaders, Pointer<Uint32> pcchReaders);

typedef _ConnectC = Int32 Function(
    IntPtr hContext,
    Pointer<Utf16> szReader,
    Uint32 dwShareMode,
    Uint32 dwPreferredProtocols,
    Pointer<IntPtr> phCard,
    Pointer<Uint32> pdwActiveProtocol);
typedef _ConnectD = int Function(
    int hContext,
    Pointer<Utf16> szReader,
    int dwShareMode,
    int dwPreferredProtocols,
    Pointer<IntPtr> phCard,
    Pointer<Uint32> pdwActiveProtocol);

typedef _TransmitC = Int32 Function(
    IntPtr hCard,
    Pointer pioSendPci,
    Pointer<Uint8> pbSendBuffer,
    Uint32 cbSendLength,
    Pointer pioRecvPci,
    Pointer<Uint8> pbRecvBuffer,
    Pointer<Uint32> pcbRecvLength);
typedef _TransmitD = int Function(
    int hCard,
    Pointer pioSendPci,
    Pointer<Uint8> pbSendBuffer,
    int cbSendLength,
    Pointer pioRecvPci,
    Pointer<Uint8> pbRecvBuffer,
    Pointer<Uint32> pcbRecvLength);

typedef _DisconnectC = Int32 Function(IntPtr hCard, Uint32 dwDisposition);
typedef _DisconnectD = int Function(int hCard, int dwDisposition);

class NfcService {
  NfcService._();
  static final NfcService instance = NfcService._();

  DynamicLibrary? _lib;

  bool get isSupported => Platform.isWindows;

  DynamicLibrary get _winscard {
    _lib ??= DynamicLibrary.open('winscard.dll');
    return _lib!;
  }

  /// Returns the list of connected reader names.
  Future<List<String>> listReaders() async {
    if (!isSupported) {
      throw const NfcException('NFC reading is only supported on Windows.');
    }
    final establish = _winscard
        .lookupFunction<_EstablishContextC, _EstablishContextD>('SCardEstablishContext');
    final release =
        _winscard.lookupFunction<_ReleaseContextC, _ReleaseContextD>('SCardReleaseContext');
    final listReaders =
        _winscard.lookupFunction<_ListReadersC, _ListReadersD>('SCardListReadersW');

    final phContext = calloc<IntPtr>();
    try {
      if (establish(_scardScopeUser, nullptr, nullptr, phContext) != _scardSuccess) {
        throw const NfcException('Could not start the smart card service.');
      }
      final hContext = phContext.value;
      try {
        return _readerNames(listReaders, hContext);
      } finally {
        release(hContext);
      }
    } finally {
      calloc.free(phContext);
    }
  }

  List<String> _readerNames(_ListReadersD listReaders, int hContext) {
    final pcch = calloc<Uint32>();
    try {
      // First call with null buffer to get required length.
      var rv = listReaders(hContext, nullptr, nullptr, pcch);
      if (rv != _scardSuccess || pcch.value == 0) return [];
      final len = pcch.value;
      final buffer = calloc<Uint16>(len);
      try {
        rv = listReaders(hContext, nullptr, buffer.cast<Utf16>(), pcch);
        if (rv != _scardSuccess) return [];
        return _parseMultiString(buffer, pcch.value);
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(pcch);
    }
  }

  /// Multi-string: reader names separated by \0, terminated by \0\0.
  List<String> _parseMultiString(Pointer<Uint16> buffer, int len) {
    final result = <String>[];
    final sb = StringBuffer();
    for (var i = 0; i < len; i++) {
      final code = buffer[i];
      if (code == 0) {
        if (sb.isEmpty) break; // double null -> end
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.writeCharCode(code);
      }
    }
    return result;
  }

  /// Waits (polls) for a card, reads its UID, and returns it as an uppercase
  /// hex string (e.g. "04A2B3C4"). Throws [NfcException] on timeout/error.
  ///
  /// [timeout] is how long to wait for a card to be tapped.
  /// [shouldCancel], if provided, is polled between read attempts; returning
  /// true aborts the scan and throws an [NfcCancelledException].
  Future<String> readCardUid(
      {Duration timeout = const Duration(seconds: 20),
      bool Function()? shouldCancel}) async {
    if (!isSupported) {
      throw const NfcException('NFC reading is only supported on Windows.');
    }

    final establish = _winscard
        .lookupFunction<_EstablishContextC, _EstablishContextD>('SCardEstablishContext');
    final release =
        _winscard.lookupFunction<_ReleaseContextC, _ReleaseContextD>('SCardReleaseContext');
    final connect = _winscard.lookupFunction<_ConnectC, _ConnectD>('SCardConnectW');
    final transmit = _winscard.lookupFunction<_TransmitC, _TransmitD>('SCardTransmit');
    final disconnect =
        _winscard.lookupFunction<_DisconnectC, _DisconnectD>('SCardDisconnect');

    final phContext = calloc<IntPtr>();
    try {
      if (establish(_scardScopeUser, nullptr, nullptr, phContext) != _scardSuccess) {
        throw const NfcException('Could not start the smart card service.');
      }
      final hContext = phContext.value;
      try {
        final listFn =
            _winscard.lookupFunction<_ListReadersC, _ListReadersD>('SCardListReadersW');
        var readers = _readerNames(listFn, hContext);
        if (readers.isEmpty) {
          throw const NfcException(
              'No card reader detected. Plug in the NFC reader and try again.');
        }

        // Poll for a card. Try EVERY reader interface each cycle — dual-interface
        // readers expose separate contact + contactless slots, and the tapped
        // card may land on any of them.
        final deadline = DateTime.now().add(timeout);
        var refreshCounter = 0;
        while (DateTime.now().isBefore(deadline)) {
          if (shouldCancel?.call() ?? false) {
            throw const NfcCancelledException();
          }
          for (final reader in readers) {
            final uid =
                _tryReadUid(connect, transmit, disconnect, hContext, reader);
            if (uid != null && uid.isNotEmpty) return uid;
          }
          await Future.delayed(const Duration(milliseconds: 300));
          // Occasionally re-list readers in case one (re)appears.
          if (++refreshCounter % 6 == 0) {
            final fresh = _readerNames(listFn, hContext);
            if (fresh.isNotEmpty) readers = fresh;
          }
        }
        throw const NfcException('No card detected. Please tap the card and try again.');
      } finally {
        release(hContext);
      }
    } finally {
      calloc.free(phContext);
    }
  }

  /// Attempts one connect+GET DATA. Returns UID hex or null if no card yet.
  String? _tryReadUid(_ConnectD connect, _TransmitD transmit,
      _DisconnectD disconnect, int hContext, String reader) {
    final readerPtr = reader.toNativeUtf16();
    final phCard = calloc<IntPtr>();
    final pdwProto = calloc<Uint32>();
    try {
      final rv = connect(hContext, readerPtr, _scardShareShared,
          _scardProtocolT0 | _scardProtocolT1, phCard, pdwProto);
      if (rv != _scardSuccess) {
        // No card present yet (or reader busy). Signal "keep polling".
        return null;
      }
      final hCard = phCard.value;
      try {
        return _getUid(transmit, hCard, pdwProto.value);
      } finally {
        // Reset the card on disconnect so the session is fully released and
        // the SAME card can be read again on the next tap (otherwise the
        // reader keeps it "in use" and subsequent connects fail).
        final rd = disconnect(hCard, _scardResetCard);
        if (rd != _scardSuccess) {
          disconnect(hCard, _scardUnpowerCard);
        }
      }
    } finally {
      calloc.free(readerPtr);
      calloc.free(phCard);
      calloc.free(pdwProto);
    }
  }

  /// Sends FF CA 00 00 00 and returns the UID (strips the 90 00 status word).
  String? _getUid(_TransmitD transmit, int hCard, int activeProtocol) {
    // SCARD_IO_REQUEST: the correct pci pointer depends on protocol.
    // winscard exports g_rgSCardT0Pci / g_rgSCardT1Pci; we build one inline.
    final pioSend = calloc<Uint32>(2);
    // dwProtocol
    pioSend[0] = activeProtocol == _scardProtocolT0 ? _scardProtocolT0 : _scardProtocolT1;
    // cbPciLength = sizeof(SCARD_IO_REQUEST) = 8
    pioSend[1] = 8;

    final sendApdu = <int>[0xFF, 0xCA, 0x00, 0x00, 0x00];
    final sendBuf = calloc<Uint8>(sendApdu.length);
    for (var i = 0; i < sendApdu.length; i++) {
      sendBuf[i] = sendApdu[i];
    }
    final recvLen = calloc<Uint32>();
    recvLen.value = 256;
    final recvBuf = calloc<Uint8>(256);

    try {
      final rv = transmit(hCard, pioSend.cast(), sendBuf, sendApdu.length,
          nullptr, recvBuf, recvLen);
      if (rv != _scardSuccess) return null;

      final n = recvLen.value;
      if (n < 2) return null;
      // Last two bytes are the status word (expect 90 00).
      final sw1 = recvBuf[n - 2];
      final sw2 = recvBuf[n - 1];
      if (sw1 != 0x90 || sw2 != 0x00) return null;

      final uidBytes = Uint8List(n - 2);
      for (var i = 0; i < n - 2; i++) {
        uidBytes[i] = recvBuf[i];
      }
      if (uidBytes.isEmpty) return null;
      return uidBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join();
    } finally {
      calloc.free(pioSend);
      calloc.free(sendBuf);
      calloc.free(recvLen);
      calloc.free(recvBuf);
    }
  }

}
