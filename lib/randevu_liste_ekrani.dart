import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RandevuEkraniTabs extends StatelessWidget {
  const RandevuEkraniTabs({super.key});

  Future<List<Map<String, dynamic>>> randevulariGetir({required bool guncel}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('randevular')
        .where('hastaUid', isEqualTo: user.uid)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id; // Firestore belgesinin ID'sini ekle
      return data;
    }).where((data) {
      final tarihParts = (data['tarih'] as String).split('-');
      final saatParts = (data['saat'] as String).split(':');
      final randevuZamani = DateTime(
        int.parse(tarihParts[0]),
        int.parse(tarihParts[1]),
        int.parse(tarihParts[2]),
        int.parse(saatParts[0]),
        int.parse(saatParts[1]),
      );
      return guncel ? randevuZamani.isAfter(now) : randevuZamani.isBefore(now);
    }).toList();
  }

  Future<void> randevuIptalEt(String docId) async {
    await FirebaseFirestore.instance.collection('randevular').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Randevularım",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF0B2D50),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Güncel"),
              Tab(text: "Geçmiş"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            buildRandevuListesi(context, guncel: true),
            buildRandevuListesi(context, guncel: false),
          ],
        ),
      ),
    );
  }

  Widget buildRandevuListesi(BuildContext context, {required bool guncel}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: randevulariGetir(guncel: guncel),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(guncel ? "Güncel randevunuz yok." : "Geçmiş randevu bulunamadı."));
        }

        final randevular = snapshot.data!;
        return ListView.builder(
          itemCount: randevular.length,
          itemBuilder: (context, index) {
            final r = randevular[index];
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text("Doktor: ${r['doktor']}"),
                subtitle: Text("Tarih: ${r['tarih']}  Saat: ${r['saat']}"),
                trailing: guncel
                    ? ElevatedButton(
                  onPressed: () async {
                    final onay = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Randevu İptali"),
                        content: const Text(
                            "Bu randevuyu iptal etmek istediğinize emin misiniz?"),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Vazgeç")),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("İptal Et")),
                        ],
                      ),
                    );

                    if (onay == true) {
                      await randevuIptalEt(r['docId']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Randevu iptal edildi.")),
                      );
                      (context as Element).reassemble();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child:
                  const Text("Randevuyu İptal Et", style: TextStyle(fontSize: 13)),
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}


