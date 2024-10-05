import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rc168/main.dart';
import 'package:rc168/pages/shop/shop_payment_page.dart';
import 'package:rc168/pages/member/address/address_cart_page.dart';
import 'package:text_responsive/text_responsive.dart';
import 'package:rc168/responsive_text.dart';
import 'package:rc168/pages/shop/shop_payment_bankTransfer_page.dart';

class ShopCartPage extends StatefulWidget {
  final String? addressId;
  const ShopCartPage({super.key, this.addressId});

  @override
  _ShopCartPageState createState() => _ShopCartPageState();
}

class _ShopCartPageState extends State<ShopCartPage> {
  List<Product> products = [];
  bool isLoading = true;
  double totalAmount = 0.0;
  int? _selectedShippingMethodCode;
  String? _selectedPaymentMethod;
  double _selectedShippingCost = 0.0;
  double _tempTotalAmount = 0.0;
  List<DropdownMenuItem<String>> _dropdownItems = [];
  List<Coupon> availableCoupons = [];
  Coupon? selectedCoupon;
  double discountedAmount = 0.0;
  double discountAmount = 0.0;

  @override
  void initState() {
    super.initState();
    fetchCartItems();
    _fetchPaymentMethods();
    getCustomerDataAndFetchAddress(widget.addressId);
    if (widget.addressId != null) {
      String? address = widget.addressId;
      setState(() {
        fetchCustomerAddress(defaultAddressId: address!);
      });
    } else {
      getCustomerDataAndFetchAddress(widget.addressId);
    }
    fetchAvailableCoupons();
  }

  Future<void> fetchAvailableCoupons() async {
    try {
      final response = await dio
          .get('${appUri}/gws_appcoupon/getAvailableCoupons&api_key=${apiKey}');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['message'][0]['msg_status'] == true) {
          setState(() {
            availableCoupons = (data['coupons'] as List)
                .map((coupon) => Coupon.fromJson(coupon))
                .where((coupon) => coupon.status == 'Enabled')
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching coupons: $e');
    }
  }

  void showCouponDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('選擇折價券'),
              content: SingleChildScrollView(
                child: Column(
                  children: availableCoupons.map((coupon) {
                    bool isApplicable =
                        totalAmount >= double.parse(coupon.total);
                    return ListTile(
                      title: Text(coupon.name),
                      subtitle: Text(
                          '${coupon.type == 'F' ? 'NT\$' : ''}${coupon.discount}${coupon.type == 'P' ? '%' : ''}'),
                      leading: Radio<Coupon>(
                        value: coupon,
                        groupValue: selectedCoupon,
                        onChanged: isApplicable
                            ? (Coupon? value) {
                                setState(() {
                                  selectedCoupon = value;
                                });
                              }
                            : null,
                      ),
                      enabled: isApplicable,
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('確定'),
                  onPressed: () {
                    applySelectedCoupon();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void applySelectedCoupon() {
    setState(() {
      if (selectedCoupon != null) {
        if (selectedCoupon!.type == 'F') {
          // 固定金额折价
          discountAmount = double.parse(selectedCoupon!.discount);
          discountedAmount = totalAmount - discountAmount;
        } else if (selectedCoupon!.type == 'P') {
          // 百分比折价
          double discountPercentage =
              double.parse(selectedCoupon!.discount) / 100;
          discountAmount =
              (totalAmount - _selectedShippingCost) * discountPercentage;
          discountedAmount = totalAmount - discountAmount;
        }
      } else {
        discountAmount = 0.0;
        discountedAmount = totalAmount;
      }
    });
  }

  Future<void> getCustomerDataAndFetchAddress(String? defaultAddressId) async {
    if (defaultAddressId != null) {
      await fetchCustomerAddress(defaultAddressId: defaultAddressId);
    } else {
      try {
        // 從 gws_customer 獲取用戶資料
        var customerResponse = await dio.get('${appUri}/gws_customer',
            queryParameters: {'customer_id': customerId, 'api_key': apiKey});
        var customer = customerResponse.data;

        // 提取 default_address_id
        String defaultAddressId =
            customer['customer'][0]['default_address_id'] ?? '';
        customerData = customer;
        // 使用提取的 default_address_id 調用 fetchCustomerAddress
        await fetchCustomerAddress(defaultAddressId: defaultAddressId);
      } catch (e) {
        print(e);
        // 處理異常或顯示錯誤信息
      }
    }
  }

  Future<void> fetchCartItems() async {
    final customerCartUrl =
        '${appUri}/gws_appcustomer_cart&customer_id=${customerId}&api_key=${apiKey}';
    final productDetailBaseUrl = '${appUri}/gws_product&product_id=';

    setState(() {
      products.clear();
      totalAmount = 0.0;
      isLoading = true;
    });
    try {
      // Fetch the cart items
      var cartResponse = await dio.get(customerCartUrl);
      var cartData = cartResponse.data;

      if (cartData['message'][0]['msg_status'] == true) {
        // Fetch details for each product in the cart
        for (var cartItem in cartData['customer_cart']) {
          var productResponse = await dio.get(
              '$productDetailBaseUrl${cartItem['product_id']}&api_key=${apiKey}');
          var productData = productResponse.data;

          if (productData['message'][0]['msg_status'] == true) {
            // Parse cart item option
            var cartItemOption = jsonDecode(cartItem['option']);
            var productOptions = productData['product'][0]['options'];

            var selectedOptions = [];
            productOptions.forEach((option) {
              var productOptionId = option['product_option_id'].toString();
              if (cartItemOption.containsKey(productOptionId)) {
                var productOptionValueId = cartItemOption[productOptionId];
                var optionValue = option['product_option_value'].firstWhere(
                    (value) =>
                        value['product_option_value_id'].toString() ==
                        productOptionValueId,
                    orElse: () => null);

                if (optionValue != null) {
                  selectedOptions.add({
                    'product_option_id': option['product_option_id'].toString(),
                    'product_option_value_id':
                        optionValue['product_option_value_id'].toString(),
                    'type': option['type'],
                    'value': optionValue['name'],
                    'name': option['name'],
                    'option_value': option['product_option_value'].map((value) {
                      return {
                        'product_option_value_id':
                            value['product_option_value_id'].toString(),
                        'option_value_id': value['option_value_id'].toString(),
                        'name': value['name'],
                        'image': value['image'],
                        'quantity': value['quantity'],
                        'subtract': value['subtract'],
                        'price': value['price'],
                        'price_prefix': value['price_prefix'],
                        'weight': value['weight'],
                        'weight_prefix': value['weight_prefix']
                      };
                    }).toList()
                  });
                }
              }
            });

            // Create combined data map
            var combinedData =
                Map<String, dynamic>.from(productData['product'][0])
                  ..addAll({
                    'quantity': cartItem['quantity'],
                    'cart_id': cartItem['cart_id'],
                    'options': selectedOptions,
                    'totals': cartData['totals']
                  });

            var product = Product.fromJson(combinedData);
            print(cartData['totals']);

            setState(() {
              products.add(product);
              product.special != false
                  ? totalAmount += product.special * product.quantity
                  : totalAmount += product.price * product.quantity;

              product.special != false
                  ? _tempTotalAmount += product.special * product.quantity
                  : _tempTotalAmount += product.price * product.quantity;
            });
          }
        }
      }
    } on DioException catch (e) {
      // Handle errors
      print(e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchCustomerAddress({String defaultAddressId = ''}) async {
    try {
      // 如果有提供 defaultAddressId，則直接使用
      String addressId = defaultAddressId;
      // print{'addressId 1: ${addressId}');

      if (addressId.isEmpty) {
        // 如果沒有提供 defaultAddressId，則從 gws_customer 獲取
        var customerResponse = await dio.get('${appUri}/gws_customer',
            queryParameters: {'customer_id': customerId, 'api_key': apiKey});
        var customerData = customerResponse.data;
        addressId = customerData['default_address_id'] ?? '';
      }

      Response addressResponse;
      if (addressId.isNotEmpty) {
        // print('fetchCustomerAddress: ${addressId}');
        // Fetch specific address
        addressResponse = await dio.get('$appUri/gws_customer_address',
            queryParameters: {
              'customer_id': customerId,
              'address_id': addressId,
              'api_key': apiKey
            });
      } else {
        // Fetch first address from address list
        addressResponse = await dio.get('${appUri}/gws_customer_address',
            queryParameters: {'customer_id': customerId, 'api_key': apiKey});
      }

      var addressData = addressResponse.data;

      setState(() {
        // 根據 status 決定如何處理地址
        if (addressData['message'][0]['msg_status']) {
          customerAddress = addressData['customer_address'][0];
        } else {
          // 如果 status 為 false，選擇最新地址或其他邏輯
        }

        // print{'customerAddress: ${customerAddress} addressId：${addressId}，');
      });
    } catch (e) {
      print(e);
      // Handle exceptions or show error messages
    }
  }

  Future<Map<String, dynamic>?> fetchCountryAndZoneDetails(
      String countryId) async {
    try {
      // 獲取國家信息
      var countryResponse = await dio.get('$appUri/gws_country',
          queryParameters: {'country_id': countryId, 'api_key': apiKey});
      var countryData = countryResponse.data;

      // 檢查國家信息是否成功獲取
      if (countryData['message'][0]['msg_status'] == true) {
        // 獲取區域列表
        var zoneResponse = await dio.get('$appUri/gws_zone',
            queryParameters: {'country_id': countryId, 'api_key': apiKey});
        var zoneData = zoneResponse.data;

        // 檢查區域信息是否成功獲取
        if (zoneData['message'][0]['msg_status'] == true) {
          // 假定您需要第一個區域的信息
          var firstZone =
              zoneData['zones'].isNotEmpty ? zoneData['zones'][0] : null;

          if (firstZone != null) {
            // 返回國家和區域的詳細信息
            return {'country': countryData['country'][0], 'zone': firstZone};
          }
        }
      }
    } on DioException catch (e) {
      print(e);
    }
    return null;
  }

  Widget buildShippingMethodList(List<ShippingMethod> methods) {
    if (methods.isNotEmpty) {
      // 確保只在方法第一次被調用時設置
      if (_selectedShippingMethodCode == null) {
        _selectedShippingMethodCode = methods.first.sortOrder!;
        _selectedShippingCost = methods.first.cost.toDouble();
        totalAmount = _tempTotalAmount + _selectedShippingCost;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: ResponsiveText(
            '物流方式',
            baseFontSize: 34, // 字體大小
            fontWeight: FontWeight.bold, // 字體加粗
          ),
        ),
        ...methods.map((method) {
          if (methods.isNotEmpty) {
            _selectedShippingMethodCode = methods.first.sortOrder!;
          }
          return ListTile(
            leading: Radio<int>(
              value: method.sortOrder!,
              groupValue: _selectedShippingMethodCode, // 將 groupValue 設置為選中的值
              onChanged: (int? value) {
                setState(() {
                  _selectedShippingMethodCode = value!;
                  _selectedShippingCost = method.cost.toDouble();
                  totalAmount = _tempTotalAmount;
                  totalAmount = totalAmount + _selectedShippingCost;
                });
              },
            ),
            title: ResponsiveText(
              method.title,
              baseFontSize: 32, // 字體大小
            ),
            trailing: ResponsiveText(
              'NT\$${method.cost}',
              baseFontSize: 34, // 字體大小
              fontWeight: FontWeight.bold, // 字體加粗
            ),
            onTap: () {
              setState(() {
                _selectedShippingMethodCode = method.sortOrder;
                _selectedShippingCost = method.cost.toDouble();
                totalAmount = _tempTotalAmount;
                totalAmount = totalAmount + _selectedShippingCost;
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Future<List<ShippingMethod>> fetchShippingMethods() async {
    final response = await dio.get(
      '${appUri}/gws_appshipping_methods/index',
      queryParameters: {
        'api_key': apiKey,
        'customer_id': customerId,
        'address_id': customerAddress!['address_id'],
      },
    );

    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(response.data);
      if (data['message'][0]['msg_status'] == true) {
        List<ShippingMethod> shippingMethods = List<ShippingMethod>.from(
          data['shipping_methods'].map((item) => ShippingMethod.fromJson(item)),
        ).where((method) {
          // 確保 sortOrder 是正數並且沒有錯誤
          return !method.error;
        }).toList();

        return shippingMethods;
      }
    }
    throw Exception('Failed to load shipping methods');
  }

  Future<void> submitOrder() async {
    if (_selectedPaymentMethod == null || _selectedShippingMethodCode == null) {
      // 顯示警告對話框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: ResponsiveText('溫馨提醒!', baseFontSize: 38),
            content: ResponsiveText(
              '您尚未選定付款方式或物流方式。',
              baseFontSize: 36,
              maxLines: 5,
            ),
            actions: <Widget>[
              TextButton(
                child: ResponsiveText('確定', baseFontSize: 36),
                onPressed: () {
                  Navigator.of(context).pop(); // 關閉對話框
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 计算折價金额
    double couponDiscount = 0.0;

    // 如果 selectedCoupon 不存在，跳過計算折價金額
    if (selectedCoupon != null) {
      if (selectedCoupon!.type == 'F') {
        couponDiscount = double.parse(selectedCoupon!.discount);
      } else if (selectedCoupon!.type == 'P') {
        couponDiscount = (totalAmount - couponDiscount) *
            (double.parse(selectedCoupon!.discount) / 100);
      }
    }

    // 構建請求體數據
    final orderData = {
      'address_id': customerAddress!['address_id'],
      'customer': customerData!['customer'],
      'products': products.map((product) {
        return {
          'product_id': product.productId,
          'quantity': product.quantity,
          'price': product.special != false ? product.special : product.price,
          'total': product.special != false
              ? product.special * product.quantity
              : product.price * product.quantity,
          'name': product.name,
          'options': product.options.map((option) {
            return {
              'product_option_id': option.productOptionId,
              'product_option_value_id': option.productOptionValueId,
              'type': option.type,
              'value': option.value,
              'name': option.name,
            };
          }).toList(),
        };
      }).toList(),
      'shipping_sort_order': _selectedShippingMethodCode,
      'payment_method': _selectedPaymentMethod,
      'shipping_cost': _selectedShippingCost,
      'totals': _extractTotalsFromProducts(products), // 提取 totals
      'amount': discountedAmount,
      'coupon_price': selectedCoupon != null ? couponDiscount.toString() : '',
    };

    if (selectedCoupon != null) {
      orderData['coupon'] = {
        'coupon_id': selectedCoupon!.couponId,
        'name': selectedCoupon!.name,
        'code': selectedCoupon!.code,
        'type': selectedCoupon!.type,
        'discount': selectedCoupon!.discount,
      };
    }

    print(orderData['totals']);

    dio.post('${demoUrl}/api/product/order/data/${customerId}',
        data: orderData);

    final response =
        await dio.get('${demoUrl}/api/product/submit/${customerId}');

    if (response.statusCode == 200) {
      final responseData = response.data['data'];

      // print(
      // 'Order submitted successfully: ${responseData['order']['order_id']}');

      //TODO: 跳轉到付款頁面
      final htmlUrl =
          '${demoUrl}/api/product/payment?customerId=${customerId}&orderId=' +
              responseData['order']['order_id'] +
              '&api_key=${apiKey}';

      // print(_selectedPaymentMethod);

      if (_selectedPaymentMethod == 'bank_transfer') {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ShopPaymentBankTransferPage(htmlUrl: htmlUrl)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ShopPaymentPage(htmlUrl: htmlUrl)),
        );
      }
    } else {
      print('Failed to submit order: ${response.statusCode}');
    }
  }

  Future<void> _fetchPaymentMethods() async {
    final response = await dio.get(
        '${appUri}/gws_apppayment_methods/index&customer_id=${customerId}&api_key=${apiKey}');

    print(response.data);

    if (response.statusCode == 200) {
      final data = response.data;
      final paymentMethods = data['payment_methods'] as List;

      setState(() {
        _dropdownItems = paymentMethods.map((method) {
          return DropdownMenuItem<String>(
            value: method['code'],
            child: Text(method['title']),
          );
        }).toList();
      });
    } else {
      throw Exception('Failed to load payment methods');
    }
  }

  // 更新 _extractTotalsFromProducts 方法
  String _extractTotalsFromProducts(List<Product> products) {
    if (products.isEmpty) {
      return "0";
    }

    double subtotal = 0;
    for (var product in products) {
      subtotal += (product.special != false ? product.special : product.price) *
          product.quantity;
    }

    double discount = 0;
    if (selectedCoupon != null) {
      if (selectedCoupon!.type == 'F') {
        discount = double.parse(selectedCoupon!.discount);
      } else if (selectedCoupon!.type == 'P') {
        discount = subtotal * (double.parse(selectedCoupon!.discount) / 100);
      }
    }

    double total = subtotal - discount;

    return total.toStringAsFixed(0); // 返回不带小数点的整数字符串
  }

  String splitByLengthAndJoin(String str, int length,
      {String separator = ' '}) {
    List<String> parts = [];
    for (int i = 0; i < str.length; i += length) {
      int end = (i + length < str.length) ? i + length : str.length;
      parts.add(str.substring(i, end));
    }
    return parts.join(separator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('購物車'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4F4E4C),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty // 如果產品列表為空
              ? Center(
                  // 顯示購物車空的提示畫面
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.shopping_cart,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      InlineTextWidget(
                        '您的購物車是空的!',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ResponsiveText(
                            '商品+運費總計',
                            baseFontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                          ResponsiveText(
                            'NT\$${totalAmount.toStringAsFixed(0)}',
                            baseFontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: Colors.grey,
                      thickness: 0.5,
                      height: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: showCouponDialog,
                        child: Text('選擇折價券'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4F4E4C),
                          side: const BorderSide(color: Color(0xFF4F4E4C)),
                        ),
                      ),
                    ),
                    if (selectedCoupon != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ResponsiveText(
                              '已選折價券：${selectedCoupon!.name}',
                              baseFontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            ResponsiveText(
                              'NT\$${discountAmount.toStringAsFixed(0)}',
                              baseFontSize: 32,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    if (selectedCoupon != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ResponsiveText(
                              '折價後金額',
                              baseFontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                            ResponsiveText(
                              'NT\$${discountedAmount.toStringAsFixed(0)}',
                              baseFontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: ResponsiveText('付款方式',
                              baseFontSize: 34, fontWeight: FontWeight.bold),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              isDense: true,
                            ),
                            isExpanded: true,
                            value: _selectedPaymentMethod,
                            items: _dropdownItems,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedPaymentMethod = value;
                              });
                            },
                            hint: Text('選擇付款方式'),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 100.0),
                        children: [
                          if (customerAddress != null)
                            FutureBuilder<Map<String, dynamic>?>(
                              future: fetchCountryAndZoneDetails(
                                  customerAddress!['country_id']),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map<String, dynamic>?>
                                      snapshot) {
                                if (snapshot.hasData) {
                                  final countryDetails =
                                      snapshot.data!['country'];
                                  final zoneDetails = snapshot.data!['zone'];
                                  return ListTile(
                                    title: ResponsiveText('收貨地址',
                                        baseFontSize: 34,
                                        fontWeight: FontWeight.bold),
                                    subtitle: ResponsiveText(
                                      '${customerAddress!['firstname']} ${customerAddress!['lastname']} \n' +
                                          '${customerAddress!['address_1']} ${customerAddress!['address_2']} \n' +
                                          '${zoneDetails['name']}, ${countryDetails['name']} \n' +
                                          '${customerAddress!['postcode']}',
                                      baseFontSize: 30,
                                      maxLines: 10,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AddressCartAddPage()),
                                        );
                                      },
                                    ),
                                  );
                                } else {
                                  return const Text('正在加載地址信息...');
                                }
                              },
                            ),
                          ...products
                              .map((product) => ListTile(
                                    leading: Image.network(
                                      '${imgUrl}' + product.thumbUrl,
                                      width: 80,
                                    ),
                                    title: ResponsiveText(
                                      product.name,
                                      baseFontSize: 36,
                                      maxLines: 4,
                                    ),
                                    subtitle: Row(
                                      children: [
                                        ResponsiveText(
                                            '數量: ${product.quantity}',
                                            baseFontSize: 28),
                                      ],
                                    ),
                                    trailing: ResponsiveText(
                                        product.special != false
                                            ? 'NT\$${(product.special * product.quantity).toStringAsFixed(0)}'
                                            : 'NT\$${(product.price * product.quantity).toStringAsFixed(0)}',
                                        baseFontSize: 28,
                                        fontWeight: FontWeight.bold),
                                  ))
                              .toList(),
                          FutureBuilder<List<ShippingMethod>>(
                            future: fetchShippingMethods(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasData) {
                                return buildShippingMethodList(snapshot.data!);
                              } else {
                                return const Text('暫無可用的物流方式');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomSheet: Container(
        color: Colors.white,
        width: double.infinity, // 容器宽度占满整个屏幕宽度
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: isLoading
              ? ElevatedButton(
                  onPressed: () {
                    submitOrder();
                  },
                  child: const InlineTextWidget(
                    '確定下訂單',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey, // 按钮背景颜色为灰色
                    foregroundColor: Color(0xFF4F4E4C), // 文本颜色为白色
                    minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6), // 圆角矩形按钮
                    ),
                  ),
                )
              : products.isEmpty
                  ? ElevatedButton(
                      onPressed: () {
                        // 当购物车为空时，跳转到逛逛賣場
                        selectedIndex = 0;
                        Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => MyApp()));
                      },
                      child: InlineTextWidget('逛逛賣場',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // 按钮背景颜色为蓝色
                        foregroundColor: Color(0xFF4F4E4C), // 文本颜色为白色
                        minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        submitOrder();
                      },
                      child: InlineTextWidget('確定下訂單',
                          style: const TextStyle(
                              fontSize: 18, color: Color(0xFF4F4E4C))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // 按钮背景颜色为蓝色
                        foregroundColor: Color(0xFF4F4E4C), // 文本颜色为白色
                        minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.black), // 圆角矩形按钮
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class Product {
  final String productId;
  final String name;
  final String thumbUrl;
  final int price;
  int quantity;
  final String cartId;
  final dynamic special;
  final List<Option> options; // 添加 options 属性
  final List<Map<String, dynamic>> totals; // 添加 totals 属性

  void incrementQuantity() {
    quantity++;
  }

  void decrementQuantity() {
    if (quantity > 0) {
      quantity--;
    }
  }

  Product({
    required this.productId,
    required this.name,
    required this.thumbUrl,
    required this.price,
    required this.quantity,
    required this.cartId,
    required this.special,
    required this.options, // 添加 options 参数
    required this.totals, // 添加 totals 参数
  });

  factory Product.fromJson(Map<String, dynamic> combinedJson) {
    // 解析 options
    List<Option> options = [];
    if (combinedJson['options'] != null) {
      var optionData = combinedJson['options'];
      if (optionData is List) {
        options = optionData.map((entry) {
          return Option(
            productOptionId: entry['product_option_id'],
            productOptionValueId: entry['product_option_value_id'],
            type: entry['type'],
            value: entry['value'],
            name: entry['name'],
          );
        }).toList();
      } else {
        // 处理其他意外类型
        print('Unexpected options data type: ${optionData.runtimeType}');
      }
    }

    // 解析 totals
    List<Map<String, dynamic>> totals = [];
    if (combinedJson['totals'] != null) {
      var totalsData = combinedJson['totals'];
      if (totalsData is List) {
        totals = totalsData.map((entry) {
          return {
            'code': entry['code'],
            'title': entry['title'],
            'text': entry['text'],
          };
        }).toList();
      } else {
        // 处理其他意外类型
        print('Unexpected totals data type: ${totalsData.runtimeType}');
      }
    }

    return Product(
      productId: combinedJson['product_id'],
      name: combinedJson['name'],
      thumbUrl: combinedJson['thumb'],
      price:
          int.parse(combinedJson['price'].replaceAll(RegExp(r'[^0-9\.]'), '')),
      quantity: int.parse(combinedJson['quantity']),
      cartId: combinedJson['cart_id'],
      special: combinedJson['special'] == false
          ? false
          : int.parse(
              combinedJson['special'].replaceAll(RegExp(r'[^0-9\.]'), '')),
      options: options, // 添加 options 初始化
      totals: totals, // 添加 totals 初始化
    );
  }
}

class Option {
  final String productOptionId;
  final String productOptionValueId;
  final String type;
  final String value;
  final String name;

  Option({
    required this.productOptionId,
    required this.productOptionValueId,
    required this.type,
    required this.value,
    required this.name,
  });
}

class ShippingMethod {
  String title;
  int cost;
  String code;
  bool error;
  int? sortOrder;

  ShippingMethod({
    required this.title,
    required this.code,
    required this.cost,
    required this.error,
    required this.sortOrder,
  });

  factory ShippingMethod.fromJson(Map<String, dynamic> json) {
    // 將 sort_order 字段轉換為整數
    var sortOrderString = json['sort_order']?.toString();
    int? sortOrder = int.tryParse(sortOrderString ?? '0');

    // 將 cost 字段轉換為整數
    var costString = json['cost']?.toString();
    int cost = int.tryParse(costString ?? '0') ?? 0;

    return ShippingMethod(
      title: json['title'],
      code: json['code'],
      cost: cost,
      error: json['error'],
      sortOrder: sortOrder ?? 0,
    );
  }
}

class Coupon {
  final String couponId;
  final String name;
  final String code;
  final String type;
  final String discount;
  final String total;
  final String status;

  Coupon({
    required this.couponId,
    required this.name,
    required this.code,
    required this.type,
    required this.discount,
    required this.total,
    required this.status,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      couponId: json['coupon_id'],
      name: json['name'],
      code: json['code'],
      type: json['type'],
      discount: json['discount'],
      total: json['total'],
      status: json['status'],
    );
  }
}
