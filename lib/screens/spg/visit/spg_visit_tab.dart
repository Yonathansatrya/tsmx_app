import '../../visits/attendance_tab.dart';

class SpgVisitTab extends AttendanceTab {
  const SpgVisitTab({super.key, super.showCheckIn, super.showHistory})
    : super(spgMode: true);
}
