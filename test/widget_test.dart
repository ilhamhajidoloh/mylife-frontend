// การทดสอบ smoke test เบื้องต้นของแอป MyLife

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_mylife/main.dart';

void main() {
  testWidgets('แอปเปิดที่แท็บภาพรวมและสลับแท็บได้', (WidgetTester tester) async {
    await tester.pumpWidget(const MyLifeApp());
    await tester.pumpAndSettle();

    // แท็บภาพรวมแสดงคำทักทาย
    expect(find.textContaining('สวัสดี'), findsOneWidget);

    // มีแถบเมนู 5 แท็บ
    expect(find.byType(NavigationDestination), findsNWidgets(5));

    // สลับไปแท็บตารางเรียน
    await tester.tap(find.text('ตารางเรียน'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ภาคเรียน'), findsOneWidget);
  });
}
