import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zivlo/core/theme/app_theme.dart';
/// Home Page
/// 
/// Main landing page for the Zivlo POS app
/// Provides quick access to key features via ExtendedFloatingActionButton
/// 
/// Features:
/// - Welcome message
/// - Quick stats overview
/// - FAB to navigate to scanner
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zivlo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Text(
                '¡Bienvenido!',
                style: AppTypography.textTheme.headlineLarge?.copyWith(
                  color: AppColors.colorOnSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.spacing8),
              Text(
                'Cobra en segundos. Sin internet. Sin complicaciones.',
                style: AppTypography.textTheme.bodyLarge?.copyWith(
                  color: AppColors.colorOnSurfaceMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.spacing32),

              // Quick stats cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.spacing16,
                  mainAxisSpacing: AppSpacing.spacing16,
                  children: [
                    _buildStatCard(
                      icon: Icons.receipt_long,
                      title: 'Ventas Hoy',
                      value: '0',
                      subtitle: 'transacciones',
                    ),
                    _buildStatCard(
                      icon: Icons.attach_money,
                      title: 'Ingresos',
                      value: '\$0',
                      subtitle: 'del día',
                    ),
                    _buildStatCard(
                      icon: Icons.inventory,
                      title: 'Productos',
                      value: '0',
                      subtitle: 'en catálogo',
                    ),
                    _buildStatCard(
                      icon: Icons.print,
                      title: 'Impresiones',
                      value: '0',
                      subtitle: 'realizadas',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/scanner');
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear'),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacing8),
              decoration: BoxDecoration(
                color: AppColors.colorPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              ),
              child: Icon(
                icon,
                color: AppColors.colorPrimary,
                size: 24,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.textTheme.headlineSmall?.copyWith(
                    color: AppColors.colorOnSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacing4),
                Text(
                  title,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.colorOnSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacing2),
                Text(
                  subtitle,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.colorOnSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
