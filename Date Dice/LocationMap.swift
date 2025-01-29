//
//  LocationMap.swift
//  Date Dice
//
//  Created by Daniel Brior on 1/25/25.
//

import SwiftUI
import MapKit
import CoreLocationUI
import CoreLocation

struct LocationMap: View {
    @StateObject var locationManager = LocationManager()
    
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMeterRadius: Double = 5000.0
    @State private var currentSearchTerm: String?
    @State private var currentPoiCategory: MKPointOfInterestCategory?
    @State private var isLoading: Bool = false
    @State private var mapCameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
    
    @State var showList: Bool = false
    
    let searchTerms: [String] = [
        // Food & Drink
        "Bar",
        "Club",
        "Restaurant",
        "Cafe",
        "Coffee Shop",
        "Dessert",
        "Ice Cream",
        "Bakery",
        "Wine Tasting",
        "Brewery",
        "Distillery",
        
        // Arts & Entertainment
        "Movie Theater",
        "Art Gallery",
        "Museum",
        "Theater",
        "Concert",
        "Live Music",
        "Comedy Club",
        "Event",
        
        // Outdoors & Recreation
        "Park",
        "Garden",
        "Beach",
        "Hiking",
        "Walk",
        "Trail",
        "Zoo",
        "Aquarium",
        "Amusement Park",
        
        // Active & Fun
        "Bowling",
        "Arcade",
        "Mini Golf",
        "Skating Rink",
        "Escape Room",
        "Sports"
    ]
    
    func changeActivity() async -> Void {
        randomizeCategory()
        await performSearch()
    }
    
    private func calculateLatitudeDelta(meters: Double) -> Double {
        let earthRadius = 6_371_000.0
        return (meters / earthRadius) * (180.0 / .pi)
    }
    
    private func updateMapCamera(center: CLLocationCoordinate2D) {
        let radius = calculateLatitudeDelta(meters: selectedMeterRadius * (25.0/9.0))
        
        print("Updating camera to: \(center), radius: \(radius)")
        
        withAnimation(.easeInOut) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: radius, longitudeDelta: radius)
            ))
        }
    }
    
    private func randomizeCategory() {
        // Legacy method
        var idx = Int.random(in: 0..<searchTerms.count)
        while currentSearchTerm == searchTerms[idx] {
            idx = Int.random(in: 0..<searchTerms.count)
        }
        currentSearchTerm = searchTerms[idx]
        
        // New method
        var poiIdx = Int.random(in: 0..<poiCategories.count)
        while currentPoiCategory == poiCategories[poiIdx] {
            poiIdx = Int.random(in: 0..<poiCategories.count)
        }
        
        currentPoiCategory = poiCategories[poiIdx]
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    Map(position: $mapCameraPosition) {
                        ForEach(searchResults, id: \.self) { result in
                            Marker(item: result)
                        }
                        UserAnnotation()
                        if let location = locationManager.location {
                            MapCircle(center: location, radius: selectedMeterRadius)
                                .stroke(.blue, lineWidth: 1.0)
                                .foregroundStyle(.blue.opacity(0.1))
                        }
                    }
                    .mapStyle(.hybrid(elevation: .realistic))
                    .navigationTitle(currentSearchTerm ?? "Roll an activity")
                    .overlay(alignment: .top) {
                        VStack {
                            Picker("Search Radius", selection: $selectedMeterRadius) {
                                Text("1 km").tag(1000.0)
                                Text("5 km").tag(5000.0)
                                Text("10 km").tag(10000.0)
                                Text("20 km").tag(20000.0)
                            }
                            //                        .background(Color(UIColor.systemGray5))
                            .pickerStyle(.segmented)
                        }
                    }
                    .frame(minHeight: UIScreen.main.bounds.height * 0.5)
                    
                    VStack {
                        Spacer()
                        
                        ActivityButton(
                            onClick: changeActivity,
                            currentSearchTerm: currentSearchTerm,
                            isLoading: isLoading,
                            isDisabled: locationManager.location == nil
                        )
                        .padding(.bottom)
                    }
                    
                    if locationManager.location == nil {
                        ProgressView()
                    }
                }
                
                if showList {
                    MapList(searchResults: searchResults)
                        .background(.black)
                        .transition(.move(edge: .bottom))
////                        .animation(.spring(), value: searchResults.count > 0)
                }
            }
            .onReceive(locationManager.$location) { location in
                if locationManager.location != nil {
                    print("Valid location")
                    updateMapCamera(center: locationManager.location!)
                } else {
                    locationManager.requestLocation()
                }
            }
            .onChange(of: searchResults.count) {
                withAnimation(.easeInOut(duration: 1)) {
                    showList = searchResults.count > 0
                }
            }
            .onChange(of: selectedMeterRadius) { oldValue, newValue in
                updateMapCamera(center: locationManager.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0))
                Task {
                    await performSearch()
                }
            }
        }
    }
    
    private func addSpaces(_ str: String) -> String {
        str.reduce("") { $0 + (($1.isUppercase && !$0.isEmpty && $0.last?.isLowercase == true) ? " " : "") + String($1) }
    }
    
    private func queryByPoiCategory(category: MKPointOfInterestCategory, center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(center: center, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
        
        let categoryAsString = addSpaces("\(category.rawValue)".replacingOccurrences(of: "MKPOICategory", with: ""))
        print("\(categoryAsString)")
        currentSearchTerm = categoryAsString
        
        let latRange = (center.latitude - radius)...(center.latitude + radius)
        let lonRange = (center.longitude - radius)...(center.longitude + radius)
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            return response.mapItems.filter {
                let itemLat = $0.placemark.coordinate.latitude
                let itemLon = $0.placemark.coordinate.longitude
                return latRange.contains(itemLat) && lonRange.contains(itemLon)
            }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    private func queryByString(searchString: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchString
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: radius,
                longitudeDelta: radius
            )
        )
        
        let latRange = (center.latitude - radius)...(center.latitude + radius)
        let lonRange = (center.longitude - radius)...(center.longitude + radius)
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            return response.mapItems.filter {
                let itemLat = $0.placemark.coordinate.latitude
                let itemLon = $0.placemark.coordinate.longitude
                return latRange.contains(itemLat) && lonRange.contains(itemLon)
            }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    @MainActor
    private func performSearch() async {
        guard !isLoading, let location = locationManager.location else { return }
        
        isLoading = true
        
        let searchRadius = calculateLatitudeDelta(meters: selectedMeterRadius)
        updateMapCamera(center: locationManager.location!)
        
        let poiResults = await queryByPoiCategory(category: currentPoiCategory ?? .nightlife, center: location, radius: selectedMeterRadius)
        let stringResults = await queryByString(searchString: currentSearchTerm ?? "Club", center: location, radius: searchRadius)
        
        let combinedResults = poiResults + stringResults
        searchResults = combinedResults.reduce(into: [MKMapItem]()) { uniqueItems, item in
            // Check if an item with the same placemark coordinate already exists
            let isDuplicate = uniqueItems.contains { existingItem in
                // Compare relevant properties to determine duplicates
                return existingItem.placemark.coordinate.latitude == item.placemark.coordinate.latitude &&
                       existingItem.placemark.coordinate.longitude == item.placemark.coordinate.longitude &&
                       existingItem.name == item.name
            }
            
            if !isDuplicate {
                uniqueItems.append(item)
            }
        }
        
        isLoading = false
    }
}

struct ActivityButton : View {
    var onClick: () async -> Void
    var currentSearchTerm: String?
    var isLoading: Bool
    var isDisabled: Bool
    
    var body: some View {
        Button {
            Task {
                await onClick()
            }
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(currentSearchTerm ?? "Randomize Activity")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        .disabled(isLoading || isDisabled)
        .font(.title)
    }
}

struct MapList : View {
    var searchResults: [MKMapItem]
    
    var body: some View {
        VStack {
            List(Array(searchResults.enumerated()), id: \.element.placemark) { idx, mapItem in
                MapListItem(idx: idx, mapItem: mapItem)
            }
            .listStyle(.plain)
        }
    }
}

struct MapListItem : View {
    @State var idx: Int
    @State var mapItem: MKMapItem
    
    var body: some View {
        HStack {
            Text("\(idx)")
            Spacer()
            HStack {
                Spacer()
                Text(mapItem.name ?? "??")
            }
            Button {
                mapItem.openInMaps()
            } label: {
                Image(systemName: "map.fill")
            }
            .padding(.leading)
        }
    }
}

#Preview {
    LocationMap()
}
