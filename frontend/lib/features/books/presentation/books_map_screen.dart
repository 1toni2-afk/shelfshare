import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/map_city.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/books_repository.dart';

const _romaniaCenter = LatLng(45.9432, 24.9668);

final _mapCitiesProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getMapCities();
});

/// Hartă cu orașele care au cărți disponibile la schimb - un marker per oraș
/// (nu avem coordonate precise per anunț), cu numărul de cărți, iar la tap se
/// deschide lista cărților din acel oraș. Plăci OpenStreetMap, fără cheie API.
class BooksMapScreen extends ConsumerStatefulWidget {
  const BooksMapScreen({super.key});

  @override
  ConsumerState<BooksMapScreen> createState() => _BooksMapScreenState();
}

class _BooksMapScreenState extends ConsumerState<BooksMapScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  bool _didFitBounds = false;
  AnimationController? _flyController;

  @override
  void dispose() {
    _flyController?.dispose();
    super.dispose();
  }

  void _fitBounds(List<MapCity> cities) {
    if (_didFitBounds || cities.isEmpty) return;
    _didFitBounds = true;
    final points = cities.map((c) => LatLng(c.lat, c.lng)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
          maxZoom: 12,
        ),
      );
    });
  }

  // flutter_map nu are o mișcare animată a camerei "din cutie" - interpolăm
  // manual centrul și zoom-ul curent spre țintă, pe durata animației.
  void _flyTo(LatLng target, double zoom) {
    _flyController?.dispose();
    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    curved.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    });
    _flyController = controller;
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(_mapCitiesProvider);
    citiesAsync.whenData(_fitBounds);

    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapTitle)),
      body: citiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => CenteredScrollable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.mapLoadError),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(_mapCitiesProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (cities) => Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _romaniaCenter,
                initialZoom: 6.3,
              ),
              children: [
                TileLayer(
                  // tile.openstreetmap.org descurajează explicit folosirea directă
                  // în producție (politica lor de trafic/User-Agent) și poate
                  // degrada silențios plăcile - CartoDB servește aceleași date
                  // OpenStreetMap, gratuit, fără cheie API, cu CORS permisiv.
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.shelfshare.app',
                  maxZoom: 20,
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                    TextSourceAttribution('© CARTO'),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final city in cities)
                      Marker(
                        point: LatLng(city.lat, city.lng),
                        width: 48,
                        height: 48,
                        child: _CityMarker(
                          city: city,
                          onTap: () => _openCity(context, city),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (cities.isEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.mapEmpty),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Userul reclama ca dupa ce inchide fisa cu cartile orasului, harta ramane
  // zoom-ata pe orasul respectiv si trebuie sa dea mereu zoom out manual -
  // pastram camera de dinainte de fly-in si o restauram la inchiderea fisei.
  Future<void> _openCity(BuildContext context, MapCity city) async {
    final camera = _mapController.camera;
    final previousCenter = camera.center;
    final previousZoom = camera.zoom;
    _flyTo(LatLng(city.lat, city.lng), 11);
    await _showCityBooks(context, city);
    if (mounted) _flyTo(previousCenter, previousZoom);
  }

  Future<void> _showCityBooks(BuildContext context, MapCity city) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CityBooksSheet(city: city),
    );
  }
}

class _CityMarker extends StatelessWidget {
  const _CityMarker({required this.city, required this.onTap});
  final MapCity city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${city.count}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const Icon(Icons.location_on, color: AppColors.primary, size: 32),
        ],
      ),
    );
  }
}

class _CityBooksSheet extends ConsumerWidget {
  const _CityBooksSheet({required this.city});
  final MapCity city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<UserBook>>(
          future: ref.read(booksRepositoryProvider).browse(city: city.city, limit: 100).then((r) => r.items),
          builder: (context, snapshot) {
            return CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${city.city} · ${context.l10n.mapCityBooksCount(city.count)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(context.l10n.homeLoadError)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 20,
                        children: [
                          for (final userBook in snapshot.data ?? const <UserBook>[])
                            BookCard(
                              userBook: userBook,
                              width: 140,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/books/${userBook.id}', extra: userBook.owner);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
