// ai_design_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


class AIDesignScreen extends StatefulWidget {
  final String designStyle;
  final String roomType;

  const AIDesignScreen({
    Key? key,
    required this.designStyle,
    required this.roomType,
  }) : super(key: key);

  @override
  _AIDesignScreenState createState() => _AIDesignScreenState();
}

class _AIDesignScreenState extends State<AIDesignScreen> {
  List<Product> _products = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchRecommendedProducts();
  }

  Future<void> _fetchRecommendedProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Replace with your actual product recommendation API
      final response = await http.get(
        Uri.parse(
          'https://your-api.com/recommendations?style=${widget.designStyle}&room=${widget.roomType}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _products = List<Product>.from(
            data['products'].map((x) => Product.fromJson(x)),
          );
        });
      } else {
        throw Exception('Failed to load recommendations');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Design - ${widget.roomType}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchRecommendedProducts,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }
  Future<void> _launchProductUrl(String url) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open product page')));
  }
}

  Widget _buildContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_products.isEmpty) {
      return Center(child: Text('No products found for this design'));
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: _products[index],
          onTap: () => _launchProductUrl(_products[index].url),
        );
      },
    );
  }

  
}

class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String url;
  final bool isIkea;
  final double matchScore;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.url,
    required this.isIkea,
    required this.matchScore,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      imageUrl: json['image_url'],
      url: json['product_url'],
      isIkea: json['is_ikea'] ?? false,
      matchScore: json['match_score']?.toDouble() ?? 0.0,
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({Key? key, required this.product, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.error),
                      ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      if (product.isIkea)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'IKEA',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: product.matchScore / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getMatchColor(product.matchScore),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${product.matchScore.toStringAsFixed(0)}% match',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMatchColor(double score) {
    if (score > 75) return Colors.green;
    if (score > 50) return Colors.orange;
    return Colors.red;
  }
}
