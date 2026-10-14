import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zivlo/features/scanner/domain/entities/scan_result.dart';
import 'package:zivlo/features/scanner/presentation/bloc/scanner_bloc.dart';
import 'package:zivlo/features/scanner/presentation/bloc/scanner_event.dart';
import 'package:zivlo/features/scanner/presentation/bloc/scanner_state.dart';

class ScanResultBottomSheet extends StatefulWidget {
  final ScanResult result;
  final VoidCallback onContinueScanning;

  const ScanResultBottomSheet({
    super.key,
    required this.result,
    required this.onContinueScanning,
  });

  @override
  State<ScanResultBottomSheet> createState() => _ScanResultBottomSheetState();
}

class _ScanResultBottomSheetState extends State<ScanResultBottomSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.result.product;
    if (product == null) return const SizedBox.shrink();
    return BlocConsumer<ScannerBloc, ScannerState>(
      listener: (context, state) {
        if (state is ScannerCartUpdated) Navigator.pop(context);
      },
      builder: (context, state) {
        final saving = state is ScannerAddingToCart;
        return PopScope(
          canPop: !saving,
          child: Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text('S/ ${product.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text('Disponible: ${product.stock}'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Disminuir cantidad',
                          onPressed: !saving && _quantity > 1
                              ? () => setState(() => _quantity--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text('$_quantity'),
                        IconButton(
                          tooltip: 'Aumentar cantidad',
                          onPressed: !saving && _quantity < product.stock
                              ? () => setState(() => _quantity++) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (state is ScannerErrorState)
                      Text(state.message, style: const TextStyle(color: Colors.red)),
                    FilledButton(
                      onPressed: saving || product.stock < _quantity ? null : () {
                        context.read<ScannerBloc>().add(AddToCartRequested(
                          result: widget.result,
                          quantity: _quantity,
                        ));
                      },
                      child: Text(saving ? 'Guardando…' : 'Agregar al carrito'),
                    ),
                    TextButton(
                      onPressed: saving ? null : widget.onContinueScanning,
                      child: const Text('Continuar escaneando'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
