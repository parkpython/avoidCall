import 'package:in_app_purchase/in_app_purchase.dart';

class AppleIapService {
  AppleIapService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  Future<AppleIapCatalog> loadCatalog(Set<String> productIds) async {
    final isStoreAvailable = await _inAppPurchase.isAvailable();
    if (!isStoreAvailable) {
      return const AppleIapCatalog(
        isStoreAvailable: false,
        products: [],
        notFoundIds: [],
      );
    }

    final response = await _inAppPurchase.queryProductDetails(productIds);
    if (response.error != null) {
      throw AppleIapException(response.error!.message);
    }

    return AppleIapCatalog(
      isStoreAvailable: true,
      products: response.productDetails,
      notFoundIds: response.notFoundIDs,
    );
  }

  Future<void> buySubscription({
    required ProductDetails product,
    String? applicationUserName,
  }) async {
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: applicationUserName,
    );

    final started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!started) {
      throw const AppleIapException('구매 플로우를 시작하지 못했습니다.');
    }
  }

  Future<void> restorePurchases({String? applicationUserName}) async {
    await _inAppPurchase.restorePurchases(
      applicationUserName: applicationUserName,
    );
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(purchase);
  }
}

class AppleIapCatalog {
  const AppleIapCatalog({
    required this.isStoreAvailable,
    required this.products,
    required this.notFoundIds,
  });

  final bool isStoreAvailable;
  final List<ProductDetails> products;
  final List<String> notFoundIds;
}

class AppleIapException implements Exception {
  const AppleIapException(this.message);

  final String message;

  @override
  String toString() => message;
}
