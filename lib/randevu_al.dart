import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'randevu_liste_ekrani.dart';


const Color darkBlue = Color(0xFF0B2D50);
const Color backgroundBeige = Color(0xFFF8F5F0);

class RandevuEkrani extends StatefulWidget {
  const RandevuEkrani({super.key});

  @override
  State<RandevuEkrani> createState() => _RandevuEkraniState();
}

class _RandevuEkraniState extends State<RandevuEkrani> {
  String? secilenBolum;
  String? secilenDoktor;
  DateTime? secilenTarih;
  Future<Map<String, String>>? _saatDurumuFuture;

  List<String> bolumler = [];
  Map<String, List<String>> doktorlar = {};

  Future<String> kullaniciAdiniGetir() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Adsız Hasta";
    final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
    return doc.data()?['ad_soyad'] ?? "Adsız Hasta";
  }


  @override
  void initState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        print('🔴 Kullanıcı oturum açmamış.');
      } else {
        print('🟢 Kullanıcı oturumda: ${user.email}, UID: ${user.uid}');
      }
    });

    super.initState();
    fetchBolumlerVeDoktorlar();
  }

  Future<void> fetchBolumlerVeDoktorlar() async {
    final snapshot = await FirebaseFirestore.instance.collection('bolumler').get();
    for (var doc in snapshot.docs) {
      String bolumAdi = doc.id;
      bolumler.add(bolumAdi);
      final data = doc.data();
      List<dynamic> doktorListesi = data['doktorlar'] ?? [];
      doktorlar[bolumAdi] = doktorListesi.cast<String>();
    }
    setState(() {});
  }

  List<String> generateSaatDilimi(String baslangic, String bitis) {
    List<String> saatler = [];
    int basSaat = int.parse(baslangic.split(":")[0]);
    int basDakika = int.parse(baslangic.split(":")[1]);
    int bitSaat = int.parse(bitis.split(":")[0]);
    int bitDakika = int.parse(bitis.split(":")[1]);

    while (basSaat < bitSaat || (basSaat == bitSaat && basDakika < bitDakika)) {
      final saatStr = basSaat.toString().padLeft(2, '0');
      final dakikaStr = basDakika.toString().padLeft(2, '0');
      saatler.add("$saatStr:$dakikaStr");
      basDakika += 15;
      if (basDakika >= 60) {
        basDakika = 0;
        basSaat++;
      }
    }
    return saatler;
  }

  Future<void> randevuAl({
    required String doktor,
    required DateTime tarih,
    required String saat,
    required String hastaUid,
    required String hastaAd,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final tarihStr = "${tarih.year}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}";

    try {
      await firestore.collection('randevular').add({
        'doktor': doktor,
        'tarih': tarihStr,
        'saat': saat.padLeft(5, '0'),
        'hastaUid': hastaUid,
        'hastaAd': hastaAd,
      });
      print("✅ Firestore'a başarıyla yazıldı");
    } catch (e) {
      print("❌ Firestore'a yazılamadı: $e");
    }
  }

  Future<Map<String, String>> getSaatDurumlari(String doktorAdi, DateTime tarih) async {
    final firestore = FirebaseFirestore.instance;
    final doktorSnapshot = await firestore
        .collection('doktorlar')
        .where('ad', isEqualTo: doktorAdi)
        .get();
    if (doktorSnapshot.docs.isEmpty) return {};

    final doktor = doktorSnapshot.docs.first.data();
    List calismaGunleri = doktor['calismaGunleri'];

    String bas = doktor['mesaiBaslangic'].replaceAll('.', ':');
    String bit = doktor['mesaiBitis'].replaceAll('.', ':');

    final weekdayMap = {
      1: 'pazartesi',
      2: 'sali',
      3: 'carsamba',
      4: 'persembe',
      5: 'cuma',
      6: 'cumartesi',
      7: 'pazar'
    };
    final secilenGun = weekdayMap[tarih.weekday]!;

    List<String> calismaGunleriStr = calismaGunleri.map((e) => e.toString().toLowerCase()).toList();

    if (!calismaGunleriStr.contains(secilenGun)) {
      return {
        for (var s in generateSaatDilimi("08:00", "18:00")) s: 'kapali'
      };
    }

    final mesaiSaatleri = generateSaatDilimi(bas, bit);

    final tarihStr = "${tarih.year}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}";
    final randevuSnapshot = await firestore
        .collection('randevular')
        .where('doktor', isEqualTo: doktorAdi)
        .where('tarih', isEqualTo: tarihStr)
        .get();

    final doluSaatler = randevuSnapshot.docs
        .map((e) => (e['saat'] as String).padLeft(5, '0'))
        .toSet();

    Map<String, String> sonuc = {};
    for (var saat in generateSaatDilimi("08:00", "18:00")) {
      final normalizedSaat = saat.padLeft(5, '0');
      if (!mesaiSaatleri.contains(saat)) {
        sonuc[saat] = 'kapali';
      } else if (doluSaatler.contains(normalizedSaat)) {
        sonuc[saat] = 'dolu';
      } else {
        sonuc[saat] = 'musait';
      }
    }
    return sonuc;
  }



@override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: backgroundBeige,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/logo.png'),
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(height: 30),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Lütfen Bölüm Seçiniz',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  value: secilenBolum,
                  items: bolumler.map((bolum) {
                    return DropdownMenuItem(value: bolum, child: Text(bolum));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      secilenBolum = value;
                      secilenDoktor = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Lütfen Doktor Seçiniz',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  value: secilenDoktor,
                  items: (secilenBolum != null && doktorlar.containsKey(secilenBolum))
                      ? doktorlar[secilenBolum]!
                      .map((doktor) => DropdownMenuItem(value: doktor, child: Text(doktor)))
                      .toList()
                      : [],
                  onChanged: (value) {
                    setState(() {
                      secilenDoktor = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: darkBlue),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [
                      Text(
                        secilenTarih == null
                            ? 'Uygun Tarihler'
                            : 'Seçilen Tarih: ${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}',
                        style: const TextStyle(
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final endOfWeek = now.add(Duration(days: 7 - now.weekday));
                          final secilen = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: now,
                            lastDate: endOfWeek,
                          );
                          if (secilen != null) {
                            setState(() {
                              secilenTarih = secilen;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          foregroundColor: backgroundBeige,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Tarih Seç'),
                      ),
                      const SizedBox(height: 20),
                      if (secilenDoktor != null && secilenTarih != null)
                        FutureBuilder<Map<String, String>>(
                          future: getSaatDurumlari(secilenDoktor!, secilenTarih!),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();
                            final saatDurumu = snapshot.data!;

                            final saatButonlari = <Widget>[];
                            final entries = saatDurumu.entries.toList();
                            for (int i = 0; i < entries.length; i += 4) {
                              final rowChildren = entries.skip(i).take(4).map((entry) {
                                final renk = entry.value == 'kapali'
                                    ? Colors.grey
                                    : entry.value == 'dolu'
                                    ? Colors.red
                                    : Colors.green;
                                return Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: ElevatedButton(
                                    onPressed: entry.value == 'musait'
                                        ? () async {
                                      final user = FirebaseAuth.instance.currentUser;

                                      final onay = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Randevu Onayı'),
                                          content: Text(
                                            '${entry.key} saatine ${DateFormat('d/M/y').format(secilenTarih!)} tarihinde randevu almak üzeresiniz.\nOnaylıyor musunuz?',
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
                                          ],
                                        ),
                                      );

                                      if (onay == true && user != null) {
                                        final ad = await kullaniciAdiniGetir();
                                        await randevuAl(
                                          doktor: secilenDoktor!,
                                          tarih: secilenTarih!,
                                          saat: entry.key,
                                          hastaUid: user.uid,
                                          hastaAd: ad,
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("💙 Randevunuz başarıyla alındı.")),
                                          );
                                          setState(() {});
                                        }
                                      } else if (user == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Lütfen tekrar giriş yapın.")),
                                        );
                                      }
                                    }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: renk,
                                      fixedSize: const Size(70, 40),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(entry.key),
                                  ),
                                );
                              }).toList();

                              saatButonlari.add(Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: rowChildren,
                              ));
                            }

                            return Column(children: saatButonlari);
                          },
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: darkBlue,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RandevuEkraniTabs()),
                    );
                  },
                  icon: const Icon(Icons.calendar_month, color: Colors.white),
                  label: const Text("Randevularım", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),

      ),
    );
  }
}


