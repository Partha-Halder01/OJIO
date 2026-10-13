import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/widgets/listing_card.dart';

Future<String> imageFixture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final url =
      'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
  image.dispose();
  picture.dispose();
  return url;
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('portrait and landscape photos share an area without cropping', (
    tester,
  ) async {
    final portrait = await tester.runAsync(() => imageFixture(100, 300));
    final landscape = await tester.runAsync(() => imageFixture(300, 100));
    final urls = [portrait!, landscape!];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var index = 0; index < urls.length; index++)
                SizedBox(
                  width: 150,
                  height: 230,
                  child: ListingCard(
                    listing: ListingModel.fromJson({
                      'id': index + 1,
                      'title': 'Product',
                      'price': 100,
                      'city': 'Hyderabad',
                      'images': [
                        {'image_path': urls[index]},
                      ],
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final url in urls) {
        await precacheImage(
          MemoryImage(base64Decode(url.split(',').last)),
          tester.element(find.byType(Scaffold)),
        );
      }
    });
    await tester.pumpAndSettle();
    final areas = find.byKey(const ValueKey('listing-card-image-area'));
    expect(areas, findsNWidgets(2));
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byType(InkWell), findsNWidgets(2));
    expect(tester.getSize(areas.at(0)), tester.getSize(areas.at(1)));
    for (var index = 0; index < 2; index++) {
      final raw = find.descendant(
        of: areas.at(index),
        matching: find.byType(RawImage),
      );
      final render = tester.renderObject<RenderImage>(raw);
      expect(render.fit, BoxFit.contain);
      final source = Size(
        render.image!.width.toDouble(),
        render.image!.height.toDouble(),
      );
      final fitted = applyBoxFit(render.fit!, source, render.size);
      expect(fitted.source, source);
      expect(fitted.destination.width, lessThanOrEqualTo(render.size.width));
      expect(fitted.destination.height, lessThanOrEqualTo(render.size.height));
    }
    expect(tester.takeException(), isNull);
  });
}
