import '../../visits/customer_visit_tab.dart';

class SpgVisitTab extends CustomerVisitTab {
  const SpgVisitTab({super.key, super.showCheckIn, super.showHistory})
    : super(spgMode: true);
}
