import MapKit

let poiCategories: [MKPointOfInterestCategory] = {
    var categories: [MKPointOfInterestCategory] = [
        .museum,
        .theater,
        .library,
        .movieTheater,
        .nightlife,
        .bakery,
        .brewery,
        .cafe,
        .restaurant,
        .winery,
        .amusementPark,
        .aquarium,
        .beach,
        .campground,
        .marina,
        .nationalPark,
        .park,
        .zoo
    ]
    
    if #available(iOS 18.0, *) {
        categories.append(contentsOf: [
            .musicVenue,
            .planetarium,
            .castle,
            .fortress,
            .landmark,
            .nationalMonument,
            .distillery,
            .foodMarket,
            .fairground,
            .bowling,
            .goKart,
            .hiking,
            .miniGolf,
            .rockClimbing,
            .skating,
            .skiing,
            .fishing,
            .kayaking
        ])
    }
    
    return categories
}()
