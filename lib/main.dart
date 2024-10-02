import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'package:rc168/pages/category/category_page.dart';
import 'package:rc168/pages/home_page.dart';
import 'package:rc168/pages/member/member_page.dart';
import 'package:rc168/pages/search_page.dart';
import 'package:rc168/pages/shop/shop_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rc168/firebase_options.dart';
import 'package:flutter_responsive_framework/flutter_responsive_framework.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rc168/responsive_text.dart';

// 创建一个全局的通知插件实例
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

FirebaseMessaging messaging = FirebaseMessaging.instance;

var dio = Dio();
String appUrl = 'https://ismartdemo.com.tw';
String appUri = '${appUrl}/index.php?route=extension/module/api';
String imgUrl = '${appUrl}/image/';
String apiKey =
    'CNQ4eX5WcbgFQVkBXFKmP9AE2AYUpU2HySz2wFhwCZ3qExG6Tep7ZCSZygwzYfsF';
String demoUrl = 'https://ismartdemo.dev-laravel.co';
String tracking =
    'nXnYCxN98euUt7G1yrN69jd6jNMH4gcoO80nH4505z50IkvZbeHrOpb7vrUi5kou';
String logoImg = '';
String categoryId = '';
String email = '';
String lastName = '';
String firstName = '';
bool isLogin = false;
int customerId = 0;
String fullName = '';
int selectedIndex = 0;
Map<String, dynamic>? customerData;
Map<String, dynamic>? customerAddress;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPreferences.init();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final bool useFingerprint = prefs.getBool('useFingerprint') ?? false;
  // print{isLoggedIn);
  // print{useFingerprint);

  // firebase message notification
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final fcmToken = await FirebaseMessaging.instance.getToken();

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  // log('User granted permission: ${settings.authorizationStatus}');
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  // log("FCMToken $fcmToken");

  // runApp(MyApp());
  runApp(
    ResponsiveUIWidget(
      builder: (context, orientation, screenType) {
        return MyApp();
      },
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // 底部導航項目列表
  static List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    CategoryPage(),
    SearchPage(),
    ShopPage(),
    MemberPage(),
  ];

  @override
  void initState() {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        String? body = message.notification?.body ?? "";
        String? title = message.notification?.title ?? "";

        const androidNotificationDetails = AndroidNotificationDetails(
          'notification_channel', // 频道ID
          'Message Notifications', // 频道名称
          channelDescription: 'Notification channel for order updates',
          importance: Importance.max,
          priority: Priority.high,
          largeIcon: DrawableResourceAndroidBitmap('ic_launcher'),
        );

        const iOSNotificationDetails = DarwinNotificationDetails();

        const notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
          iOS: iOSNotificationDetails,
        );

        FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        const initializationSettingsAndroid =
            AndroidInitializationSettings('ic_launcher');
        const initializationSettingsIOS = DarwinInitializationSettings();
        const initSetttings = InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);

        flutterLocalNotificationsPlugin.initialize(initSetttings);

        await flutterLocalNotificationsPlugin.show(
            0, // channelId
            title, // notificationTitle
            body, // notificationBody
            notificationDetails);
      },
    );

    super.initState();

    // showOrderPlacedNotification();
    getSetting().then((img) {
      if (mounted) {
        setState(() {
          logoImg = '${imgUrl}' + img;
        });
      }
    }).catchError((error) {
      // 處理錯誤，例如顯示錯誤消息
      print(error);
    });

    setUserPreferences();
    //_getToken();
  }

  void _getToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    late String? token;
    token = await messaging.getToken();
    if (token != null) {
      // print{"token: $token");
      setState(() {
        // _push_token = token!;
      });
    }
  }

  void setUserPreferences() async {
    if (UserPreferences.isLoggedIn()) {
      isLogin = UserPreferences.isLoggedIn();
      email = UserPreferences.getEmail() ?? '預設電子郵件';
      fullName = UserPreferences.getFullName() ?? '預設姓名';
      customerId = UserPreferences.getCustomerId() ?? 0;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<String> getSetting() async {
    try {
      var response =
          await Dio().get('${appUri}/gws_store_settings&api_key=${apiKey}');
      return response.data['settings']['config_logo'];
    } catch (e) {
      // print{e);
      throw (e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: logoImg != null
            ? Image.network(
                logoImg,
                height: 45,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(child: CircularProgressIndicator());
                },
                errorBuilder: (BuildContext context, Object exception,
                    StackTrace? stackTrace) {
                  return SizedBox();
                },
              )
            : SizedBox(),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF4F4E4C),
        // actions: [
        //   IconButton(icon: Icon(FontAwesomeIcons.heart), onPressed: () {}),
        //   IconButton(icon: Icon(FontAwesomeIcons.comments), onPressed: () {}),
        // ],
        iconTheme: const IconThemeData(color: Color(0xFF4F4E4C)),
      ),
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7, // 設置寬度為屏幕寬度的 50%
        child: Drawer(
          backgroundColor: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Text('您好',
                      style: TextStyle(
                        fontSize: 24,
                        color: Color(0xFF4F4E4C),
                      )),
                ),
              ),
              ListTile(
                leading: const Icon(FontAwesomeIcons.circleUser),
                title: const Text('會員中心'),
                onTap: () {
                  if (isLogin == true) {
                    selectedIndex = 4;
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => MyApp()));
                  } else {
                    selectedIndex = 4;
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => MyApp()));
                  }
                },
              ),
              ListTile(
                leading: const Icon(FontAwesomeIcons.headset),
                title: const Text('線上客服'),
                onTap: () {
                  showShareDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: _widgetOptions.elementAt(selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.house),
            label: '首頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.tags),
            label: '商品分類',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.magnifyingGlass),
            label: '搜尋',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.cartShopping),
            label: '購物車',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.user),
            label: '會員中心',
          ),
        ],
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

Future<Map<String, dynamic>> fetchCustomerServiceData(int number) async {
  var dio = Dio();
  Map<String, dynamic> service = {};
  try {
    var response = await dio.get(
        '${appUri}/gws_appservice/onlineCustomerService&api_key=${apiKey}');
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['status'] == 0 || data['status'] == null) {
        // 根据number选择返回哪个服务信息
        service = data[number == 1
            ? 'online_customer_service_1'
            : 'online_customer_service_2'];
      } else {
        print('Status is not 0 or null.');
      }
    } else {
      print('Failed to fetch data: HTTP status ${response.statusCode}');
    }
  } on DioError catch (e) {
    print('Dio error: ${e.message}');
  } catch (e) {
    print('Error: $e');
  }
  return service;
}

// TODO: 加入客服中心
void showShareDialog(BuildContext context) async {
  Map<String, dynamic> fetchData1 = await fetchCustomerServiceData(1);
  Map<String, dynamic> fetchData2 = await fetchCustomerServiceData(2);
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0)), // Rounded corners
        child: Container(
          padding: EdgeInsets.all(20.0),
          height: 120, // Set the height of the dialog
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment
                    .spaceEvenly, // Center the icons horizontally
                children: <Widget>[
                  // if (fetchData1['status'] == '1')
                  IconButton(
                      icon: Icon(FontAwesomeIcons.line,
                          color: Colors.green, size: 40),
                      onPressed: () {
                        launchLINE();
                      }),
                  // if (fetchData2['status'] == '1')
                  IconButton(
                      icon: Icon(FontAwesomeIcons.facebookMessenger,
                          color: Colors.blue, size: 40),
                      onPressed: () {
                        launchFacebook();
                      }),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showNormalDialog(context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: ResponsiveText(
          title,
          baseFontSize: 36,
        ),
        content: ResponsiveText(
          message,
          baseFontSize: 30,
          maxLines: 5,
        ),
        actions: <Widget>[
          TextButton(
            child: ResponsiveText(
              '確定',
              baseFontSize: 36,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> launchLINE() async {
  const url = 'https://lin.ee/sQL6TZp';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw 'Could not launch $url';
  }
}

Future<void> launchFacebook() async {
  const url = 'https://m.me/107852265523612';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw 'Could not launch $url';
  }
}

class UserPreferences {
  static SharedPreferences? _preferences;

  static const _keyLoggedIn = 'loggedIn';
  static const _keyEmail = 'email';
  static const _keyFullName = 'fullName';
  static const _keyLastName = 'lastName';
  static const _keyFirstName = 'firstName';
  static const _keyCustomerId = '';

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setLoggedIn(bool loggedIn) async =>
      await _preferences?.setBool(_keyLoggedIn, loggedIn);

  static bool isLoggedIn() => _preferences?.getBool(_keyLoggedIn) ?? false;

  static Future setEmail(String email) async =>
      await _preferences?.setString(_keyEmail, email);

  static String? getEmail() => _preferences?.getString(_keyEmail);

  static Future setFullName(String fullName) async =>
      await _preferences?.setString(_keyFullName, fullName);

  static String? getFullName() => _preferences?.getString(_keyFullName);

  static Future setLastName(String lastName) async =>
      await _preferences?.setString(_keyLastName, lastName);

  static String? getLastName() => _preferences?.getString(_keyLastName);

  static Future setFirstName(String firstName) async =>
      await _preferences?.setString(_keyFirstName, firstName);

  static String? getFirstName() => _preferences?.getString(_keyFirstName);

  static Future setCustomerId(int customerId) async =>
      await _preferences?.setInt(_keyCustomerId, customerId);

  static int? getCustomerId() => _preferences?.getInt(_keyCustomerId);

  static Future logout() async {
    await _preferences?.setBool(_keyLoggedIn, false);
    // await _preferences?.remove(_keyEmail);
    // email = '';
    isLogin = false;
    fullName = '';
  }
}

// 通知類
Future<void> showOrderPlacedNotification(String orderId) async {
  const androidNotificationDetails = AndroidNotificationDetails(
    'order_channel', // 频道ID
    'Order Notifications', // 频道名称
    channelDescription: 'Notification channel for order updates',
    importance: Importance.max,
    priority: Priority.high,
    largeIcon: DrawableResourceAndroidBitmap('ic_launcher'),
  );

  const iOSNotificationDetails = DarwinNotificationDetails();

  const notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iOSNotificationDetails,
  );

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initSetttings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

  flutterLocalNotificationsPlugin.initialize(initSetttings);
  await flutterLocalNotificationsPlugin.show(
    5, // 通知ID
    '訂單通知', // 通知标题
    '訂單編號：${orderId}，已經訂購完成.', // 通知内容
    notificationDetails,
  );

  fetchAndRemoveCartItems();
}

Future<void> showOrderCompletedNotification() async {
  // 类似于 showOrderPlacedNotification，修改为订单完成的相关信息
}

Future<void> showOrderCancelledNotification() async {
  const androidNotificationDetails = AndroidNotificationDetails(
    'order_channel', // 频道ID
    'Order Notifications', // 频道名称
    channelDescription: 'Notification channel for order updates',
    importance: Importance.max,
    priority: Priority.high,
    largeIcon: DrawableResourceAndroidBitmap('ic_launcher'),
  );

  const iOSNotificationDetails = DarwinNotificationDetails();

  const notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iOSNotificationDetails,
  );

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initSetttings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

  flutterLocalNotificationsPlugin.initialize(initSetttings);

  await flutterLocalNotificationsPlugin.show(
    10, // 通知ID
    '訂單通知', // 通知标题
    '訂單通知 - 訂單已經取消.', // 通知内容
    notificationDetails,
  );
}

// 指紋辨識
Future<void> authenticateWithFingerprint() async {
  final LocalAuthentication auth = LocalAuthentication();
  final bool didAuthenticate = await auth.authenticate(
    localizedReason: '請使用指紋登入',
    options: const AuthenticationOptions(biometricOnly: true),
  );

  if (didAuthenticate) {
    // 認證成功，進入主界面
  } else {
    // 認證失敗，處理方式根據需求定
  }
}

Future<void> _firebaseMessagingBackgroundHandler(message) async {
  await Firebase.initializeApp();
  // print{'Handling a background message ${message.messageId}');
}

void fetchAndRemoveCartItems() async {
  var dio = Dio();
  try {
    // 发起GET请求以获取购物车数据
    final response = await dio.get(
      '${appUri}/gws_customer_cart',
      queryParameters: {
        'customer_id': customerId,
        'api_key': apiKey,
      },
    );

    if (response.statusCode == 200) {
      // 请求成功，解析购物车数据
      Map<String, dynamic> jsonData = response.data;
      List<dynamic> carts = jsonData['customer_cart'];

      // 遍历购物车项并删除它们
      for (var cart in carts) {
        removeCartItem(cart['cart_id']);
      }
    } else {
      // 错误处理
      print('Failed to fetch cart items: ${response.statusCode}');
    }
  } catch (e) {
    // 异常处理
    print('Error fetching cart items: $e');
  }
}

void removeCartItem(String cartId) async {
  var dio = Dio();
  try {
    final response = await dio.get(
      '${appUri}/gws_customer_cart/remove',
      queryParameters: {
        'customer_id': customerId,
        'cart_id': cartId,
        'api_key': apiKey,
      },
    );
    if (response.statusCode == 200) {
      // 请求成功处理
      print('Item removed successfully: ${response.data}');
    } else {
      // 错误处理
      print('Failed to remove item: ${response.statusCode}');
    }
  } catch (e) {
    // 异常处理
    print('Error removing item: $e');
  }
}
