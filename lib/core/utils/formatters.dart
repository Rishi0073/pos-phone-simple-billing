import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

final _rupeeFormatter = NumberFormat('#,##,##0', 'en_IN');

String formatMoney(num value) =>
    '${AppConstants.currencySymbol}${_rupeeFormatter.format(value)}';

String formatPlainMoney(num value) => _rupeeFormatter.format(value);

String formatNumber(num value) => _rupeeFormatter.format(value);

String formatDateTime(DateTime dt) =>
    DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());

String formatDate(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt.toLocal());

String formatBillNumber(int number) => number.toString().padLeft(6, '0');