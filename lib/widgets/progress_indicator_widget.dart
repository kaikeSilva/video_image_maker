import 'package:flutter/material.dart';

class FlowProgressIndicator extends StatelessWidget {
  final int currentStep;
  static const List<String> steps = [
    'Áudio',
    'Imagens', 
    'Edição',
    'Preview',
    'Exportação'
  ];
  
  const FlowProgressIndicator({Key? key, required this.currentStep}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final int index = entry.key;
          final bool isActive = index == currentStep;
          final bool isCompleted = index < currentStep;
          
          return Expanded(
            child: Row(
              children: [
                // Círculo do step
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? Colors.green : 
                           isActive ? Colors.blue : Colors.grey.shade300,
                  ),
                  child: Center(
                    child: isCompleted 
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                  ),
                ),
                // Linha conectora (exceto no último)
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? Colors.green : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
