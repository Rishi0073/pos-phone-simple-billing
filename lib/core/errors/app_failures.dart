abstract class AppFailure implements Exception {
  const AppFailure(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

class InvalidPrice extends AppFailure {
  const InvalidPrice() : super('Enter a valid price.');
}

class InvalidQuantity extends AppFailure {
  const InvalidQuantity() : super('Quantity must be at least 1.');
}

class EmptyBill extends AppFailure {
  const EmptyBill() : super('No items in this bill.');
}

class PrinterNotConnected extends AppFailure {
  const PrinterNotConnected() : super('Printer is not connected.');
}

class UsbPermissionDenied extends AppFailure {
  const UsbPermissionDenied() : super('Printer permission was not allowed.');
}

class UsbConnectFailed extends AppFailure {
  const UsbConnectFailed([super.message = 'Could not connect to the USB printer.']);
}

class PrinterWriteFailed extends AppFailure {
  const PrinterWriteFailed()
      : super('Could not write to the printer. Check the USB connection.');
}

class StorageFailure extends AppFailure {
  const StorageFailure([super.message = 'Could not save the bill.']);
}

class WrongPin extends AppFailure {
  const WrongPin() : super('Incorrect security PIN.');
}