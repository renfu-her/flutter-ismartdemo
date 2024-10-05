import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rc168/main.dart';
import 'package:rc168/pages/product_detail.dart';

class ShopRepurchasePage extends StatefulWidget {
  final String orderId;
  ShopRepurchasePage({required this.orderId});

  @override
  _ShopRepurchasePageState createState() => _ShopRepurchasePageState();
}

class _ShopRepurchasePageState extends State<ShopRepurchasePage> {
  late Future<OrderDetail> orderDetailFuture;

  @override
  void initState() {
    super.initState();
    orderDetailFuture = fetchOrderDetail();
  }

  Future<OrderDetail> fetchOrderDetail() async {
    Response response = await dio.get(
        '${appUri}/gws_appcustomer_order/info&customer_id=${customerId}&order_id=${widget.orderId}&api_key=${apiKey}');
    if (response.statusCode == 200) {
      return OrderDetail.fromJson(response.data);
    } else {
      throw Exception('加载产品失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('訂單詳情'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF4F4E4C),
      ),
      body: FutureBuilder<OrderDetail>(
        future: orderDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("No data found"));
          } else {
            final order = snapshot.data!.order;
            final products = snapshot.data!.products;
            final totals = snapshot.data!.totals;

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                ...products.map((product) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(8.0),
                        leading: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailPage(
                                  productId: product.productId,
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            product.image,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.option.isNotEmpty)
                              Text(
                                  '规格: ${product.option.map((option) => "${option['name']}: ${option['value']}").join(', ')}'),
                            Text('x ${product.quantity}'),
                          ],
                        ),
                        trailing: Text(
                          product.total,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                      ),
                      Divider(),
                    ],
                  );
                }).toList(),
                ...totals.map((total) {
                  return ListTile(
                    title: Text(
                      total.title,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      total.text,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: total.code == 'total'
                              ? Colors.red
                              : Colors.black),
                    ),
                  );
                }).toList(),
              ],
            );
          }
        },
      ),
    );
  }
}

class OrderDetail {
  final Order order;
  final List<Product> products;
  final List<Total> totals;

  OrderDetail({
    required this.order,
    required this.products,
    required this.totals,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    return OrderDetail(
      order: Order.fromJson(json['order'][0]),
      products:
          (json['products'] as List).map((i) => Product.fromJson(i)).toList(),
      totals: (json['totals'] as List).map((i) => Total.fromJson(i)).toList(),
    );
  }
}

class Order {
  final String orderId;
  final String firstname;
  final String lastname;
  final String total;

  Order({
    required this.orderId,
    required this.firstname,
    required this.lastname,
    required this.total,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id'] as String,
      firstname: json['firstname'] as String,
      lastname: json['lastname'] as String,
      total: json['total'] as String,
    );
  }
}

class Product {
  final String name;
  final String model;
  final String href;
  final String image;
  final String productId;
  final String price;
  final String quantity;
  final List<Map<String, String>> option;
  final String total;

  Product({
    required this.name,
    required this.model,
    required this.href,
    required this.image,
    required this.productId,
    required this.price,
    required this.quantity,
    required this.option,
    required this.total,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    String href = json['href'] as String;
    href = href.replaceAll('&amp;', '&');

    final uri = Uri.parse(href);
    final productId = uri.queryParameters['product_id'] ?? '';

    return Product(
      name: json['name'] as String? ?? '',
      model: json['model'] as String? ?? '',
      href: href,
      image: json['image'] as String? ?? '',
      productId: productId,
      price: json['price'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '',
      option: (json['option'] as List<dynamic>)
          .map((option) => {
                'name': option['name'] as String,
                'value': option['value'] as String,
              })
          .toList(),
      total: json['total'] as String? ?? '',
    );
  }
}

class Total {
  final String code;
  final String title;
  final String text;

  Total({
    required this.code,
    required this.title,
    required this.text,
  });

  factory Total.fromJson(Map<String, dynamic> json) {
    return Total(
      code: json['code'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
    );
  }
}
