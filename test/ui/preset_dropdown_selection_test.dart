import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:implate_flow/ui/core/preset_dropdown.dart';

void main() {
  for (final typed in [false, true]) {
    testWidgets('tocar num item seleciona exatamente esse item (${typed ? 'filtrado' : 'sem filtro'})', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <String>[];
      final options = ['3.5 x 8', '3.5 x 10', '4.0 x 10', '4.0 x 11.5', '4.3 x 13'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PresetDropdown(label: 'Tamanho', value: '', options: options, onChanged: selected.add),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      if (typed) {
        await tester.enterText(find.byType(TextField), '4.0');
        await tester.pumpAndSettle();
      }
      final target = typed ? '4.0 x 11.5' : '4.0 x 10';
      await tester.tap(find.text(target).hitTestable());
      await tester.pumpAndSettle();
      expect(selected, [target]);
    });
  }
}
