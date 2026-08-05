import '../../visits/customer_visit_tab.dart';

class SalesVisitTab extends CustomerVisitTab {
  const SalesVisitTab({super.key, super.showCheckIn, super.showHistory})
    : super(spgMode: false);
}

class SalesVisitCheckInScreen extends CustomerVisitCheckInScreen {
  const SalesVisitCheckInScreen({super.key}) : super(spgMode: false);
}
