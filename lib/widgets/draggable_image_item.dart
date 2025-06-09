import 'dart:io';
import 'package:flutter/material.dart';

class DraggableImageItem extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onTap;
  
  const DraggableImageItem({
    Key? key,
    required this.imagePath,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      // O dado que será arrastado é o caminho da imagem
      data: imagePath,
      // O que é mostrado enquanto arrasta
      feedback: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image, size: 40),
              );
            },
          ),
        ),
      ),
      // O que é mostrado no lugar original durante o arrasto
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildImageCard(context),
      ),
      // O widget normal
      child: _buildImageCard(context),
    );
  }

  Widget _buildImageCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 40),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Arraste para a timeline',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
