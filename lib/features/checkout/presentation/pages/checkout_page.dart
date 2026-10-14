import 'package:zivlo/features/checkout/application/usecases/get_checkout_summary.dart' as checkout_dto;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:zivlo/core/theme/app_theme.dart';
import 'package:zivlo/features/checkout/domain/value_objects/payment_method.dart';
import 'package:zivlo/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:zivlo/features/checkout/presentation/bloc/checkout_event.dart';
import 'package:zivlo/features/checkout/presentation/bloc/checkout_state.dart';
import 'package:zivlo/features/checkout/presentation/widgets/payment_method_selector.dart';
import 'package:zivlo/features/checkout/presentation/widgets/cash_payment_section.dart';
import 'package:zivlo/features/checkout/presentation/widgets/card_payment_section.dart';
import 'package:zivlo/features/checkout/presentation/widgets/mixed_payment_section.dart';
import 'package:zivlo/features/checkout/presentation/widgets/checkout_summary_widget.dart';
/// Checkout Page
/// Main payment selection and processing page
/// 
/// Displays:
/// - Order summary
/// - Payment method selector (Cash/Card/Mixed)
/// - Payment-specific input sections
/// - Confirm payment button
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalizar Venta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<CheckoutBloc>().add(const NavigateBack());
            context.pop();
          },
          tooltip: 'Volver',
        ),
        backgroundColor: AppColors.colorPrimary,
        foregroundColor: AppColors.colorOnSurface,
        elevation: 0,
      ),
      body: BlocConsumer<CheckoutBloc, CheckoutState>(
        listener: (context, state) {
          if (state is CheckoutSuccess) {
            // Navigate to success page
            context.push(
              '/checkout/success',
              extra: {
                'saleId': state.saleId,
                'totalPaid': state.totalPaid,
                'paymentMethod': state.paymentMethod,
                'change': state.change,
              },
            );
          } else if (state is CheckoutError) {
            // Show error snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.colorError,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pageMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Checkout summary
                  _buildSummarySection(context, state),

                  const SizedBox(height: AppSpacing.spacing24),

                  // Payment method selector
                  _buildPaymentMethodSelector(context, state),

                  const SizedBox(height: AppSpacing.spacing24),

                  // Payment-specific section
                  _buildPaymentSection(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, CheckoutState state) {
    checkout_dto.CheckoutSummary? summary;

    if (state is CheckoutReady) {
      summary = state.summary;
    } else if (state is CashPaymentState) {
      summary = state.summary;
    } else if (state is CardPaymentState) {
      summary = state.summary;
    } else if (state is MixedPaymentState) {
      summary = state.summary;
    }

    if (summary == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return CheckoutSummary(summary: summary, expanded: false);
  }

  Widget _buildPaymentMethodSelector(
    BuildContext context,
    CheckoutState state,
  ) {
    PaymentMethod selectedMethod = PaymentMethod.cash;

    if (state is CheckoutReady) {
      selectedMethod = state.selectedPaymentMethod;
    } else if (state is CashPaymentState) {
      selectedMethod = PaymentMethod.cash;
    } else if (state is CardPaymentState) {
      selectedMethod = PaymentMethod.card;
    } else if (state is MixedPaymentState) {
      selectedMethod = PaymentMethod.mixed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de Pago',
          style: AppTypography.textTheme.titleMedium?.copyWith(
            color: AppColors.colorOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.spacing12),
        PaymentMethodSelector(
          selectedMethod: selectedMethod,
          onMethodSelected: (method) {
            context.read<CheckoutBloc>().add(PaymentMethodSelected(method));
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSection(BuildContext context, CheckoutState state) {
    if (state is CheckoutLoading || state is CheckoutProcessing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.spacing32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state is CashPaymentState) {
      return CashPaymentSection(
        summary: state.summary,
        cashAmount: state.cashAmount,
        change: state.change,
        isValid: state.isValid,
        onAmountChanged: (value) {
          final amount = double.tryParse(value) ?? 0;
          context.read<CheckoutBloc>().add(CashAmountEntered(amount));
        },
        onConfirmPayment: () {
          context.read<CheckoutBloc>().add(const ProcessPaymentRequested());
        },
      );
    }

    if (state is CardPaymentState) {
      return CardPaymentSection(
        summary: state.summary,
        onConfirmPayment: () {
          context.read<CheckoutBloc>().add(const ProcessPaymentRequested());
        },
      );
    }

    if (state is MixedPaymentState) {
      return MixedPaymentSection(
        summary: state.summary,
        cashAmount: state.cashAmount,
        cardAmount: state.cardAmount,
        remainingAmount: state.remainingAmount,
        change: state.change,
        isValid: state.isValid,
        onCashAmountChanged: (value) {
          final amount = double.tryParse(value) ?? 0;
          context.read<CheckoutBloc>().add(CashAmountEntered(amount));
        },
        onCardAmountChanged: (value) {
          final amount = double.tryParse(value) ?? 0;
          context.read<CheckoutBloc>().add(CardAmountEntered(amount));
        },
        onConfirmPayment: () {
          context.read<CheckoutBloc>().add(const ProcessPaymentRequested());
        },
      );
    }

    // Default: show loading
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
