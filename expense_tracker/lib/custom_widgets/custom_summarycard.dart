import 'package:flutter/material.dart';

class CustomSummaryCard extends StatefulWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const CustomSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  State<CustomSummaryCard> createState() => _CustomSummaryCardState();
}

class _CustomSummaryCardState extends State<CustomSummaryCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.45,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: widget.color.withOpacity(0.75),
            child: Icon(widget.icon, color: Colors.white),
          ),
          SizedBox(width: 5),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: TextStyle(fontSize: 12)),
              Text(
                "₹${widget.amount.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 16, color: widget.color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
