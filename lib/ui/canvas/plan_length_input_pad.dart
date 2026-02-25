import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Wraps the number pad with a draggable title bar (tap-hold and drag the top to move).
class PlanDraggableNumberPadWrapper extends StatelessWidget {
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final Widget child;

  const PlanDraggableNumberPadWrapper({
    super.key,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onDragStart(),
          onPanUpdate: (d) => onDragUpdate(d.delta),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Floating number pad widget for entering wall length.
class PlanLengthInputPad extends StatefulWidget {
  final TextEditingController controller;
  final bool useImperial;
  final ValueChanged<String> onChanged;

  const PlanLengthInputPad({
    super.key,
    required this.controller,
    required this.useImperial,
    required this.onChanged,
  });

  @override
  State<PlanLengthInputPad> createState() => _PlanLengthInputPadState();
}

class _PlanLengthInputPadState extends State<PlanLengthInputPad> {
  bool get _isTouchDevice =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Widget build(BuildContext context) {
    if (_isTouchDevice) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Length',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                widget.controller.text.isEmpty
                    ? (widget.useImperial ? '0 ft' : '0 mm')
                    : widget.controller.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            _buildNumberPad(),
          ],
        ),
      );
    } else {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wall Length',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: widget.useImperial ? 'ft/in' : 'mm/cm',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: widget.onChanged,
            ),
            const SizedBox(height: 4),
            Text(
              widget.useImperial ? 'Enter feet (e.g., 10.5)' : 'Enter mm (e.g., 3000)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('1'),
            const SizedBox(width: 4),
            _buildNumberButton('2'),
            const SizedBox(width: 4),
            _buildNumberButton('3'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('4'),
            const SizedBox(width: 4),
            _buildNumberButton('5'),
            const SizedBox(width: 4),
            _buildNumberButton('6'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('7'),
            const SizedBox(width: 4),
            _buildNumberButton('8'),
            const SizedBox(width: 4),
            _buildNumberButton('9'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton('.'),
            const SizedBox(width: 4),
            _buildNumberButton('0'),
            const SizedBox(width: 4),
            _buildActionButton(Icons.backspace_outlined, () {
              if (widget.controller.text.isNotEmpty) {
                widget.controller.text = widget.controller.text
                    .substring(0, widget.controller.text.length - 1);
                widget.onChanged(widget.controller.text);
                setState(() {});
              }
            }),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(Icons.clear, () {
            widget.controller.clear();
            widget.onChanged('');
            setState(() {});
          }, label: 'Clear'),
        ),
      ],
    );
  }

  Widget _buildNumberButton(String digit) {
    return Material(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () {
          widget.controller.text += digit;
          widget.onChanged(widget.controller.text);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 32,
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, {String? label}) {
    return Material(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: label != null ? double.infinity : 36,
          height: 32,
          alignment: Alignment.center,
          padding: label != null ? const EdgeInsets.symmetric(horizontal: 8) : null,
          child: label != null
              ? Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Icon(icon, size: 18),
        ),
      ),
    );
  }
}
