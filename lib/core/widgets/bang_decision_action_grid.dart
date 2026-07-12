import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_scaling.dart';

enum BangDecisionActionTone { orange, amber, red }

class BangDecisionAction {
  const BangDecisionAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.semanticLabel,
  });

  final Key key;
  final String label;
  final IconData icon;
  final BangDecisionActionTone tone;
  final VoidCallback onPressed;
  final bool isEnabled;
  final bool isLoading;
  final String? semanticLabel;
}

class BangDecisionActionGrid extends StatelessWidget {
  const BangDecisionActionGrid({
    super.key,
    required this.actions,
    this.breakpoint = 280,
    this.spacing = 8,
  });

  final List<BangDecisionAction> actions;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < breakpoint ? 1 : 2;
        final rows = <Widget>[];

        for (var index = 0; index < actions.length; index += columns) {
          final rowActions = actions
              .skip(index)
              .take(columns)
              .toList(growable: false);
          rows.add(
            Row(
              children: [
                for (
                  var rowIndex = 0;
                  rowIndex < rowActions.length;
                  rowIndex++
                ) ...[
                  if (rowIndex > 0) SizedBox(width: spacing),
                  Expanded(
                    child: _DecisionButton(action: rowActions[rowIndex]),
                  ),
                ],
              ],
            ),
          );
          if (index + columns < actions.length) {
            rows.add(SizedBox(height: spacing));
          }
        }

        return Column(children: rows);
      },
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({required this.action});

  final BangDecisionAction action;

  @override
  Widget build(BuildContext context) {
    final height = AppTextScaling.adaptive(context, normal: 52, large: 64);
    final (foregroundColor, borderColor) = switch (action.tone) {
      BangDecisionActionTone.orange => (
        AppColors.primaryDark,
        AppColors.primary,
      ),
      BangDecisionActionTone.amber => (
        AppColors.warningDark,
        AppColors.warning,
      ),
      BangDecisionActionTone.red => (AppColors.error, AppColors.error),
    };
    final enabled = action.isEnabled && !action.isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.semanticLabel ?? action.label,
      child: SizedBox(
        height: height,
        child: OutlinedButton.icon(
          key: action.key,
          onPressed: enabled ? action.onPressed : null,
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.white),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? AppColors.textMuted
                  : foregroundColor;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? AppColors.border
                    : borderColor,
              );
            }),
            overlayColor: WidgetStatePropertyAll(
              foregroundColor.withValues(alpha: 0.08),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          icon: action.isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              : Icon(action.icon, size: 18),
          label: Text(
            action.isLoading ? 'Memproses...' : action.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
