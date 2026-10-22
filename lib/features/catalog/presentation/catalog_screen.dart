import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../domain/product.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  static const List<MasterProduct> masterCatalog = [
    MasterProduct(
      id: 'prod_orange_01',
      title: 'Nagpur Oranges (1 kg)',
      description: 'Farm-fresh Nagpur sweet oranges directly sourced from grower cooperatives.',
      category: 'Fruits',
      unit: 'kg',
      thumbnailUrl: '',
    ),
    MasterProduct(
      id: 'prod_rice_01',
      title: 'Miniket Premium Rice (25 kg bag)',
      description: 'Polished long-grain Miniket rice harvested from Dinajpur paddy farms.',
      category: 'Grains',
      unit: 'bag',
      thumbnailUrl: '',
    ),
    MasterProduct(
      id: 'prod_oil_01',
      title: 'Mustard Oil Cold-Pressed (5 Liter)',
      description: 'Pure cold-pressed mustard oil with pungent aroma from organic seeds.',
      category: 'Oils',
      unit: 'bottle',
      thumbnailUrl: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Master Product Catalog', style: theme.textTheme.h4),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: masterCatalog.length,
        itemBuilder: (context, index) {
          final product = masterCatalog[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ShadCard(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(product.title, style: theme.textTheme.large),
                  ShadBadge.outline(child: Text(product.category)),
                ],
              ),
              description: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(product.description, style: theme.textTheme.muted),
              ),
              footer: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Base Unit: ${product.unit}', style: theme.textTheme.small),
              ),
            ),
          );
        },
      ),
    );
  }
}
