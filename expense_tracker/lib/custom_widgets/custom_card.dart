import 'package:flutter/material.dart';

class CustomCard extends StatefulWidget {
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final Function()? onTap;
  const CustomCard({super.key,required this.leadingIcon, required this.title, required this.subtitle, required this.trailingIcon, this.onTap});

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(widget.leadingIcon, color: Colors.black, size: 36),
        minTileHeight: 70,
        tileColor: Colors.white,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            widget.title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(widget.subtitle, style: TextStyle(fontSize: 16)),
        ),
        trailing: Icon(widget.trailingIcon, color: Colors.black, size: 28),
        onTap: widget.onTap,
      ),
    );
  }
}
