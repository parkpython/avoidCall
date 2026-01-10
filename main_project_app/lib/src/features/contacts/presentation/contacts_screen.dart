import 'package:flutter/material.dart';

class Contact {
  final String name;
  final String phoneNumber;

  Contact({
    required this.name,
    required this.phoneNumber,
  });
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Contact> contacts = [
      Contact(name: 'John Doe', phoneNumber: '555-1234'),
      Contact(name: 'Jane Smith', phoneNumber: '555-5678'),
      Contact(name: 'Peter Jones', phoneNumber: '555-9012'),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(contact.name),
              subtitle: Text(contact.phoneNumber),
            );
          },
        ),
      ),
    );
  }
}
