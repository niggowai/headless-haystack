import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:headless_haystack/accessory/accessory_icon.dart';
import 'package:headless_haystack/accessory/accessory_model.dart';
import 'package:headless_haystack/accessory/accessory_registry.dart';
import 'package:headless_haystack/location/location_model.dart';
import 'package:provider/provider.dart';

class AccessoryMap extends StatefulWidget {
  final MapController? mapController;

  /// Displays a map with all accessories at their latest position.
  const AccessoryMap({
    Key? key,
    this.mapController,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _AccessoryMapState();
  }
}

class _AccessoryMapState extends State<AccessoryMap> {
  late MapController _mapController;
  void Function()? cancelLocationUpdates;
  void Function()? cancelAccessoryUpdates;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();

    var accessoryRegistry =
        Provider.of<AccessoryRegistry>(context, listen: false);
    var locationModel = Provider.of<LocationModel>(context, listen: false);

    // Resize map to fit all accessories at initial locaiton
    fitToContent(accessoryRegistry.accessories, locationModel.here);

    // Fit map if first location is known
    void listener() {
      // Only use the first location, cancel further updates
      cancelLocationUpdates?.call();
      fitToContent(accessoryRegistry.accessories, locationModel.here);
    }

    locationModel.addListener(listener);
    cancelLocationUpdates = () => locationModel.removeListener(listener);

    // Fit map if accessories change?
  }

  @override
  void dispose() {
    super.dispose();

    cancelLocationUpdates?.call();
    cancelAccessoryUpdates?.call();
  }

  void fitToContent(List<Accessory> accessories, LatLng? hereLocation) async {
    // Delay to prevent race conditions
    await Future.delayed(const Duration(milliseconds: 500));

    List<LatLng> points = [];
    if (hereLocation != null) {
      _mapController
        ..move(hereLocation, _mapController.zoom)
        ..move(_mapController.center, _mapController.zoom + 0.00001);
      points = [hereLocation];
    }

    List<LatLng> accessoryPoints = accessories
        .where((accessory) => accessory.lastLocation != null)
        .map((accessory) => accessory.lastLocation!)
        .toList();
    if (accessoryPoints.isNotEmpty) {
      _mapController
        ..fitBounds(LatLngBounds.fromPoints([...points, ...accessoryPoints]),
            options: const FitBoundsOptions(
              padding: EdgeInsets.all(25),
            ))
        ..move(_mapController.center, _mapController.zoom + 0.00001);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(builder:
        (BuildContext context, AccessoryRegistry accessoryRegistry,
            LocationModel locationModel, Widget? child) {
      // Zoom map to fit all accessories on first accessory update
      var accessories = accessoryRegistry.accessories;
      fitToContent(accessories, locationModel.here);

      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: locationModel.here ?? const LatLng(51.1657, 10.4515),
          maxZoom: 18.0,
          minZoom: 2.0,
          zoom: 13.0,
          interactiveFlags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.pinchMove,
        ),
        children: [
          TileLayer(
            backgroundColor: Theme.of(context).colorScheme.surface,
            tileBuilder: (context, child, tile) {
              var isDark = (Theme.of(context).brightness == Brightness.dark);
              return isDark
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,
                        0,
                        0,
                        0,
                        255,
                        0,
                        -1,
                        0,
                        0,
                        255,
                        0,
                        0,
                        -1,
                        0,
                        255,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: child,
                    )
                  : child;
            },
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              ...accessories
                  .where((accessory) => accessory.lastLocation != null)
                  .map((accessory) => Marker(
                        rotate: true,
                        width: 50,
                        height: 50,
                        point: accessory.lastLocation!,
                        builder: (ctx) => AccessoryIcon(
                            icon: accessory.icon, color: accessory.color),
                      ))
                  .toList(),
            ],
          ),
          MarkerLayer(markers: [
            if (locationModel.here != null)
              Marker(
                width: 25.0,
                height: 25.0,
                point: locationModel.here!,
                builder: (ctx) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).indicatorColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ]),
        ],
      );
    });
  }
}
