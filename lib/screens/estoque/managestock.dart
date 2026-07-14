import 'package:DELLALIO/screens/estoque/edit_item_screen.dart';
import 'package:DELLALIO/screens/estoque/register_item_screen.dart';
import 'package:DELLALIO/screens/estoque/stock_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/user_session.dart';

class ManageStockScreen extends StatefulWidget {
  const ManageStockScreen({super.key});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  String _searchQuery = "";
  bool _isStockCritical(int current, int min) {
    return current <= (min + 10);
  }

  void _showCriticalStockDialog(BuildContext context, String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "⚠️ ALERTA DE ESTOQUE",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          height: 100,
          child: Center(
            child: Text(
              "O item $itemName está com o estoque perigosamente baixo! Por favor, reponha imediatamente.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockGridCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    int quantity = data['quantity'] ?? 0;
    int minQuantity = data['minQuantity'] ?? 0;
    bool isCritical = _isStockCritical(quantity, minQuantity);

    return Card(
      clipBehavior:
          Clip.antiAlias, // Essencial para o borderRadius do Container
      color: isCritical ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: () {
          if (isCritical) {
            _showCriticalStockDialog(context, data['name'] ?? 'Item');
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditItemScreen(docId: id, data: data),
            ),
          );
        },
        child:  SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(top: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // Centraliza verticalmente no card
              children: [
                Column(
                  children: [ // Removido o crossAxisAlignment: start daqui para centralizar
           CachedNetworkImage(
                  imageUrl: data['imageUrl'] ?? '',
                  imageBuilder: (context, imageProvider) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(width: 2, color: Colors.yellow),
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (context, url) => const CircleAvatar(
                    radius: 60,
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                ),
            const SizedBox(height: 20),
            Text(
              (data['name'] ?? 'SEM NOME').toUpperCase(),
              textAlign: TextAlign.center, // Garante centralização do texto
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Qtd: $quantity | Min: $minQuantity",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isCritical ? Colors.redAccent : Colors.white70,
                fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
              ),
            ),
                  ],
                  ),
                
                SizedBox(height: 30),
                const Divider(height: 1, color: Colors.white24),
                Container(
                  width: double.infinity,
                  height: 45,
                  color: isCritical ? Colors.red : const Color(0xFFD4AF37),
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(docId: id, data: data),
                      ),
                    ),
                    icon: Icon(
                      UserSession.isAdmin() ? Icons.edit : Icons.visibility,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      !UserSession.isAdmin()
                          ? "VER DETALHES"
                          : (isCritical ? "REPOR ESTOQUE" : "EDITAR ITEM"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = UserSession.isAdmin();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "GERENCIAR ESTOQUE",
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.history, color: Color(0xFFD4AF37)),
              tooltip: 'Histórico de Retiradas',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockHistoryScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [

Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    
                    labelText: "Buscar Produto",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20))
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              if (isAdmin)
                ElevatedButton(
                  child: Text('Novo Produto',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterItemScreen())),
                 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green,fixedSize: const Size(150, 50), 
      // Define o formato como um retângulo com cantos levemente arredondados
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8)))
                ),
            ],
          ),
        ),


          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stock')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  );
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery);
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 colunas
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio:
                        1.386, // Ajuste este valor para controlar a altura do card
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    return _buildStockGridCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
