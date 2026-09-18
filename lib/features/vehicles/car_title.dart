/// A screen about one car, headed with whose it is: "Golf · Tyres".
///
/// With two cars in a garage a screen headed only "Tyres" was anybody's. Just
/// [title] while the car is not known yet, rather than a blank where its name
/// will be.
String carTitle(String? carName, String title) =>
    carName == null || carName.isEmpty ? title : '$carName · $title';
