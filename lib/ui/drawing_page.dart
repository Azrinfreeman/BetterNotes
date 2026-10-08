import 'package:flutter/material.dart';

import '../data/note.dart';

class InkPreview extends StatelessWidget {
  const InkPreview({super.key, required this.strokes, this.onTap});
  final List<InkStroke> strokes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomPaint(
        painter: _InkPainter(strokes),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);
  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(
          stroke.points.first[0] * size.width,
          stroke.points.first[1] * size.height,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point[0] * size.width, point[1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key, required this.initial});
  final List<InkStroke> initial;

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  late List<InkStroke> _strokes;
  List<List<double>>? _active;
  int _color = 0xFF514059;

  @override
  void initState() {
    super.initState();
    _strokes = [...widget.initial];
  }

  void _point(Offset position, Size size, {required bool start}) {
    final point = [
      (position.dx / size.width).clamp(0.0, 1.0),
      (position.dy / size.height).clamp(0.0, 1.0),
    ];
    setState(() {
      if (start || _active == null) {
        _active = [point];
        _strokes = [..._strokes, InkStroke(color: _color, points: _active!)];
      } else {
        _active!.add(point);
        _strokes = [..._strokes];
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Draw on note'),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _active = null;
            _strokes = [];
          }),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _strokes),
          child: const Text('Done'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (event) =>
                      _point(event.localPosition, size, start: true),
                  onPanUpdate: (event) =>
                      _point(event.localPosition, size, start: false),
                  onPanEnd: (_) => _active = null,
                  child: CustomPaint(
                    painter: _InkPainter(_strokes),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              children: [
                for (final color in const [
                  0xFF514059,
                  0xFFBD644B,
                  0xFF387F72,
                  0xFF26232A,
                ])
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _color = color),
                    style: IconButton.styleFrom(
                      backgroundColor: Color(color),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(_color == color ? Icons.check : Icons.circle),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
