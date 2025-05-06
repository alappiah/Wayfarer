import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class LocationSearchDialog extends StatefulWidget {
  @override
  _LocationSearchDialogState createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Search Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter a location (e.g., Paris, France)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              onSubmitted: (value) => _searchLocation(value),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _searchLocation(_searchController.text),
              child: Text('Search'),
            ),
            SizedBox(height: 8),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child:
                    _searchResults.isEmpty
                        ? Center(child: Text('No results'))
                        : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              title: Text(
                                result['address'],
                              ), // This will show "City, Country"
                              subtitle:
                                  result['fullAddress'] != result['address']
                                      ? Text(result['fullAddress'])
                                      : null, // Show full address as subtitle if different
                              onTap: () {
                                Navigator.pop(context, result);
                              },
                            );
                          },
                        ),
              ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final results = <Map<String, dynamic>>[];

        for (var location in locations) {
          try {
            final placemarks = await placemarkFromCoordinates(
              location.latitude,
              location.longitude,
            );

            if (placemarks.isNotEmpty) {
              final place = placemarks.first;

              // Format address consistently as "City, Country"
              final city =
                  place.locality ??
                  place.subAdministrativeArea ??
                  place.administrativeArea ??
                  'Unknown';
              final country = place.country ?? 'Unknown';
              final formattedAddress = '$city, $country';

              results.add({
                'latitude': location.latitude,
                'longitude': location.longitude,
                'address': formattedAddress,
                'fullAddress': [
                      place.name,
                      place.thoroughfare,
                      place.locality,
                      place.administrativeArea,
                      place.country,
                    ]
                    .where((element) => element != null && element.isNotEmpty)
                    .join(', '),
              });
            }
          } catch (e) {
            print('Error getting placemark: $e');
          }
        }

        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      print('Error searching location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching for location')));
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
}
