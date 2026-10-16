import 'package:flutter/material.dart';

class WhatsAppBubbleClipper extends CustomClipper<Path> {
  final bool isMe;

  WhatsAppBubbleClipper({required this.isMe});

  @override
  Path getClip(Size size) {
    var path = Path();
    double radius = 12.0;
    double tailWidth = 10.0;
    double tailHeight = 10.0;

    if (isMe) {
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius - tailWidth, 0);
      
      // Tail
      path.lineTo(size.width, 0);
      path.lineTo(size.width - tailWidth, tailHeight);
      
      path.lineTo(size.width - tailWidth, size.height - radius);
      path.quadraticBezierTo(size.width - tailWidth, size.height, size.width - tailWidth - radius, size.height);
      path.lineTo(radius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - radius);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
    } else {
      path.moveTo(radius + tailWidth, 0);
      
      // Tail
      path.lineTo(0, 0);
      path.lineTo(tailWidth, tailHeight);
      
      path.lineTo(tailWidth, size.height - radius);
      path.quadraticBezierTo(tailWidth, size.height, tailWidth + radius, size.height);
      path.lineTo(size.width - radius, size.height);
      path.quadraticBezierTo(size.width, size.height, size.width, size.height - radius);
      path.lineTo(size.width, radius);
      path.quadraticBezierTo(size.width, 0, size.width - radius, 0);
      path.lineTo(radius + tailWidth, 0);
    }

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
