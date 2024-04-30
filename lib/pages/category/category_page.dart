import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rc168/main.dart';
import 'package:rc168/pages/category/category_detail_page.dart';
import 'package:rc168/responsive_text.dart';

class CategoryPage extends StatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final Dio dio = Dio();

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<List<Category>> fetchCategories() async {
    var dio = Dio();
    Response response = await dio
        .get('${appUri}/gws_appservice/allCategories&api_key=${apiKey}');
    if (response.statusCode == 200) {
      List<dynamic> data = response.data['categories'];
      // print(data);
      return data.map((category) => Category.fromJson(category)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分類'),
      ),
      body: FutureBuilder<List<Category>>(
        future: fetchCategories(),
        builder:
            (BuildContext context, AsyncSnapshot<List<Category>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            List<Category> categories = snapshot.data ?? [];

            return Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  Category category = categories[index];
                  return ExpansionTile(
                    leading: ClipOval(
                      child: Image.network(
                        category.image,
                        width: 60.0,
                        height: 60.0,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: ResponsiveText(
                      category.name,
                      baseFontSize: 32,
                    ),
                    children: category.children.map((childCategory) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 40.0), // 增加左邊的空白
                        child: ListTile(
                          leading: ClipOval(
                            child: Image.network(
                              childCategory.image,
                              width: 60.0,
                              height: 60.0,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: ResponsiveText(
                            childCategory.name,
                            baseFontSize: 32,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategoryDetailPage(
                                  categoryId: childCategory.categoryId,
                                  categoryName: childCategory.name,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}

class Category {
  final String name;
  final String column;
  final String href;
  final String image;
  final String categoryId;
  final List<Category> children;

  Category({
    required this.name,
    required this.column,
    required this.href,
    required this.image,
    required this.children,
    required this.categoryId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'] as String? ?? '',
      children: json['children'] != null
          ? (json['children'] as List<dynamic>)
              .map((childJson) =>
                  Category.fromJson(childJson as Map<String, dynamic>))
              .toList()
          : [],
      column: json['column'] as String? ?? '',
      href: json['href'] as String? ?? '',
      image: json['image'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
    );
  }
}
