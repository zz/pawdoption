import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoder/geocoder.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animals.dart';
import 'api.dart';
import 'protos/pet_search_options.pb.dart';
import 'settings.dart';
import 'widgets/pet_button.dart';
import 'widgets/swiping_cards.dart';

/// The swiping page of the application.
class SwipingPage extends StatefulWidget {
  SwipingPage({Key key, this.feed}) : super(key: key);

  final AnimalFeed feed;

  @override
  _SwipingPageState createState() => new _SwipingPageState(this.feed);
}

class _SwipingPageState extends State<SwipingPage>
    with SingleTickerProviderStateMixin {
  _SwipingPageState(AnimalFeed feed) {
    _updateLikedList();
  }

  _updateLikedList() {
    SharedPreferences.getInstance().then((prefs) {
      var liked = prefs.getStringList('liked') ?? List<String>();
      if (liked.isNotEmpty)
        widget.feed.liked =
            liked.map((repr) => Animal.fromString(repr)).toList();
    });
  }

  Future<bool> _initializeAnimalList() async {
    var prefs = await SharedPreferences.getInstance();
    String zip = prefs.getString('zip');
    final animalType = prefs.getBool('animalType') ?? false;
    final options = prefs.getString('searchOptions');
    List<Animal> liked = prefs
        .getStringList('liked')
        .map((str) => Animal.fromString(str))
        .toList();

    var zipFromUser = await _getLocationFromUser();
    if (zipFromUser != null && zip == null) {
      zip = zipFromUser;
      prefs.setString('zip', zip);
    }
    if (zip == null) return false;
    if (zip != widget.feed.zip ||
        widget.feed.reloadFeed ||
        animalType != (widget.feed.animalType == 'cat')) {
      return await widget.feed.initialize(zip,
          animalType: animalType ? 'cat' : 'dog',
          options: PetSearchOptions.fromJson(options),
          liked: liked);
    }
    return true;
  }

  Future<String> _getLocationFromUser() async {
    String zip;
    var location = Location();
    try {
      var currentLocation = await location.getLocation;
      widget.feed.userLat = currentLocation['latitude'];
      widget.feed.userLng = currentLocation['longitude'];
      widget.feed.geoLocationEnabled = true;
      final coords = Coordinates(widget.feed.userLat, widget.feed.userLng);
      var address = await Geocoder.local.findAddressesFromCoordinates(coords);
      // TOOD: There is a bug in Geocoder right now where the postal code is
      // always null so we have to retrieve it this way for now. Remember to
      // change this once the bug is fixed.
      final zipReg = RegExp(r'[A-Z]{2} (\d{5})');
      var zipMatches = zipReg.allMatches(address.first.addressLine);
      if (zipMatches.length != 0) {
        zip = zipMatches.first.group(1);
      }
    } on Exception {
      widget.feed.geoLocationEnabled = false;
    }
    return zip;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2.0,
        centerTitle: true,
        title: Text("Pawdoption",
            style: TextStyle(
              fontFamily: 'LobsterTwo',
            )),
      ),
      body: Center(
        child: FutureBuilder(
          future: _initializeAnimalList(),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return CircularProgressIndicator(
                  strokeWidth: 1.0,
                );
              default:
                if (snapshot.hasError)
                  return Text('Couldn\'t fetch the feed :( Try again later?');
                if (snapshot.data == false) return _buildNoInfoPage();
                return Column(
                  children: [
                    SizedBox(height: 20.0),
                    SwipingCards(
                      feed: widget.feed,
                    ),
                    SizedBox(height: 15.0),
                    _buildButtonRow(),
                  ],
                );
            }
          },
        ),
      ),
    );
  }

  Widget _buildNoInfoPage() {
    const infoStyle = TextStyle(fontSize: 15.0);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text("You haven't set your location!", style: infoStyle),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Go to the ', style: infoStyle),
              RaisedButton(
                elevation: 5.0,
                onPressed: () {
                  Navigator.push(
                      context,
                      PageRouteBuilder(
                          maintainState: false,
                          pageBuilder: (context, _, __) =>
                              SettingsPage(feed: widget.feed)));
                },
                color: Colors.white,
                shape: CircleBorder(),
                padding: const EdgeInsets.all(10.0),
                child: Icon(
                  Icons.settings,
                  size: 15.0,
                  color: Colors.grey,
                ),
              ),
              Text("page and set your location", style: infoStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtonRow() {
    const num size = 35.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        PetButton(
          padding: const EdgeInsets.all(10.0),
          onPressed: () {
            if (widget.feed.skipped.isNotEmpty) widget.feed.notifier.undo();
          },
          child: Icon(
            Icons.replay,
            size: size / 2,
            color: Colors.yellow[700],
          ),
        ),
        PetButton(
          padding: const EdgeInsets.all(12.0),
          onPressed: () => widget.feed.notifier.skipCurrent(),
          child: Icon(
            Icons.close,
            size: size,
            color: Colors.red,
          ),
        ),
        PetButton(
          padding: const EdgeInsets.all(12.0),
          onPressed: () => widget.feed.notifier.likeCurrent(),
          child: Icon(
            Icons.favorite,
            size: size,
            color: Colors.green,
          ),
        ),
        PetButton(
          padding: const EdgeInsets.all(10.0),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SettingsPage(feed: widget.feed))),
          child: Icon(
            Icons.settings,
            size: size / 2,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
