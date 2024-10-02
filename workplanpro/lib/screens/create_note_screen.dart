import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateNoteScreen extends StatefulWidget {
  @override
  _CreateNoteScreenState createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  DateTime currentDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('dd MMM. yyyy').format(currentDate);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text('NOTE'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C5217),
              ),
            ),
            SizedBox(height: 8.0),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'หัวข้อ',
              ),
            ),
            SizedBox(height: 8.0),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'เนื้อหา',
              ),
              maxLines: 5,
            ),
            SizedBox(height: 16.0),
            Row(
              children: List.generate(3, (index) {
                return IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.star_border,
                    color: Color(0xFF0C5217),
                  ),
                );
              }),
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFD15353),
                  ),
                  child: Text(
                    'ลบ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF40884B),
                  ),
                  child: Text(
                    'บันทึก',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
