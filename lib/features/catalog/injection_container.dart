import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zivlo/features/catalog/infrastructure/models/product_hive_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Domain - Repository
import 'package:zivlo/features/catalog/domain/repositories/product_repository.dart';

// Infrastructure - Repositories
import 'package:zivlo/features/catalog/infrastructure/repositories/hive_product_repository.dart';

// Application - Use Cases
import 'package:zivlo/features/catalog/application/usecases/product_usecases.dart';

// Presentation - BLoC
import 'package:zivlo/features/catalog/presentation/bloc/catalog_bloc.dart';

/// Global service locator for catalog feature
final GetIt sl = GetIt.instance;

/// Initialize catalog feature dependencies
void initializeDependencies() {
  // Register Repository (LazySingleton - single instance)
  sl.registerLazySingleton<IProductRepository>(
    () => HiveProductRepository(Hive.box<ProductHiveModel>('products')),
  );
  
  // Register Use Cases (LazySingleton - stateless)
  sl.registerLazySingleton(() => GetProductByBarcode(sl()));
  sl.registerLazySingleton(() => GetAllProducts(sl()));
  sl.registerLazySingleton(() => CreateProduct(sl()));
  sl.registerLazySingleton(() => UpdateProduct(sl()));
  sl.registerLazySingleton(() => DeleteProduct(sl()));
  sl.registerLazySingleton(() => SearchProducts(sl()));
  
  // Register BLoC (Factory - new instance per widget)
  sl.registerFactory(() => CatalogBloc(
        getAllProducts: sl(),
        getProductByBarcode: sl(),
        createProduct: sl(),
        updateProduct: sl(),
        deleteProduct: sl(),
        searchProducts: sl(),
      ));
}

/// Get BLoC providers for this feature
List<BlocProvider> getBlocProviders() {
  return [
    BlocProvider<CatalogBloc>(create: (_) => sl<CatalogBloc>()),
  ];
}
