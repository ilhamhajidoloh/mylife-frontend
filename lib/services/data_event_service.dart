import 'dart:async';

/// บริการส่งสัญญาณกลางเพื่อแจ้งเตือนเมื่อมีการเปลี่ยนแปลงข้อมูลในระบบ (เช่น การเงิน, Todolist, ตารางเรียน, กิจกรรม, งาน)
class DataEventService {
  static final StreamController<void> _dataChangeController = StreamController<void>.broadcast();

  /// Stream สำหรับคอยรับสัญญาณเมื่อข้อมูลมีการอัพเดต
  static Stream<void> get onDataChanged => _dataChangeController.stream;

  /// เรียกใช้ฟังก์ชันนี้เมื่อมีการ เพิ่ม, แก้ไข หรือ ลบ ข้อมูลใดๆ ในระบบ
  static void notifyDataChanged() {
    _dataChangeController.add(null);
  }
}
