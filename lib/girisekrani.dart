import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hastane_randevu_app/randevu_al.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color backgroundBeige = Color(0xFFF8F5F0);
const Color darkBlue = Color(0xFF0B2D50);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HastaneApp());
}

class HastaneApp extends StatelessWidget {
  const HastaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Özel Şakaoğlu Hastanesi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: backgroundBeige,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderSide: BorderSide(color: darkBlue)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: darkBlue)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: darkBlue, width: 2)),
          labelStyle: TextStyle(color: darkBlue),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: darkBlue),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 96),
            const SizedBox(height: 24),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const RandevuEkrani()),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Giriş başarısız: $e")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lütfen tüm alanları doldurunuz")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBlue,
                foregroundColor: backgroundBeige,
              ),
              child: const Text('Giriş Yap'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text('Kayıt Ol'),
            )
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? validatePassword(String value) {
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumberOrSymbol = value.contains(RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]'));
    final isLongEnough = value.length >= 8;

    if (!isLongEnough) return 'Şifre en az 8 karakter olmalı';
    if (!hasUpper) return 'Şifre büyük harf içermeli';
    if (!hasLower) return 'Şifre küçük harf içermeli';
    if (!hasNumberOrSymbol) return 'Şifre en az 1 sayı veya sembol içermeli';
    if (dobController.text.isNotEmpty &&
        value.contains(dobController.text.replaceAll('/', ''))) {
      return 'Şifre doğum tarihi içermemeli';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundBeige,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkBlue),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 96),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  validator: (value) => value == null || value.isEmpty ? 'Ad soyad girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                  validator: (value) => value == null || value.isEmpty ? 'E-posta girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: dobController,
                  decoration: const InputDecoration(labelText: 'Doğum Tarihi (gg/aa/yyyy)'),
                  keyboardType: TextInputType.datetime,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      dobController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
                    }
                  },
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Doğum tarihi girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Şifre girin' : validatePassword(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre Tekrar'),
                  validator: (value) =>
                  value != passwordController.text ? 'Şifreler eşleşmiyor' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        // 🔐 Firebase Authentication'a kayıt
                        UserCredential userCredential = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                          email: emailController.text,
                          password: passwordController.text,
                        );

                        // 👤 Firestore'a ek bilgiler kaydedilsin
                        await FirebaseFirestore.instance
                            .collection('kullanicilar')
                            .doc(userCredential.user!.uid)
                            .set({
                          'ad_soyad': nameController.text,
                          'email': emailController.text,
                          'dogum_tarihi': dobController.text,
                          'kayit_tarihi': Timestamp.now(),
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kayıt başarılı!')),
                        );

                        Navigator.pop(context);
                      } catch (e) {
                        print("🔥 Hata: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Hata oluştu: $e")),
                        );
                      }
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: backgroundBeige,
                  ),
                  child: const Text('Kayıt Ol'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
