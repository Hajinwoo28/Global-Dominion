import 'package:flutter/material.dart';

void main() {
  runApp(const GlobalDominion());
}

class GlobalDominion extends StatelessWidget {
  const GlobalDominion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Dominion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
  width: double.infinity,
  decoration: const BoxDecoration(
  image: DecorationImage(
    image: AssetImage('assets/images/world_map.jpg'),
    fit: BoxFit.cover,
  ),
),
  child: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),
  ),
)
    );
  }
}