//
//  LocationMap.swift
//  Date Dice
//
//  Created by Daniel Brior on 1/25/25.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError: any Error) {
        print("Error getting location")
    }
}

struct LocationMap: View {
    @StateObject var locationManager = LocationManager()
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchRadius: Double = 0.01
    @State private var selectedMeterRadius: Double = 500.0
    
    @State var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417), span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    
    @State var currentSearchTerm: String?
    
    @State var isLoading: Bool = false
    
    var searchTerms: [String]  = [
        "Bar",
        "Club",
        "Restaruant",
        "Sport",
        "Walk",
        "Surfing"
    ]
    
    func calculateLatitudeDelta(meters: Double) -> Double {
        // Earth's radius in meters
        let earthRadius = 6_371_000.0
        
        // Convert meters to degrees of latitude
        let latitudeDelta = (meters / earthRadius) * (180.0 / .pi)
        
        return latitudeDelta
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    if isLoading {
                        ProgressView()
                    }
                    
                    Map {
                        ForEach(searchResults, id: \.self) { result in
                            Marker(item: result)
                        }
                        UserAnnotation()
                    }
                    .mapStyle(.hybrid(elevation: .realistic))
                    .navigationTitle(currentSearchTerm ?? "Roll an activity")
                    .overlay(alignment: .top) {
    //                    if let location = locationManager.location {
    //                        Text("Your location: \(location.latitude), \(location.longitude)")
    //                    }
                        Picker("Search Radius", selection: $selectedMeterRadius) {
                            Text("1 km").tag(1000.0)
                            Text("5 km").tag(5000.0)
                            Text("10 km").tag(10000.0)
                            Text("20 km").tag(20000.0)
                        }
                        .pickerStyle(.segmented)
                        
                    }
                    .overlay(alignment: .bottom) {
                        if locationManager.location == nil{
                            LocationButton {
                                locationManager.requestLocation()
                            }
                        } else {
                            Button(currentSearchTerm ?? "Randomize Activity") {
                                let idx = Int.random(in: 0..<searchTerms.count)
                                isLoading = true
                                
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentSearchTerm = searchTerms[idx]
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.extraLarge)
                            .disabled(isLoading)
                            .backgroundStyle(isLoading ? .gray : .blue)
                            .font(.title)
                            .onChange(of: currentSearchTerm) {
                                if currentSearchTerm != nil {
                                    searchRadius = calculateLatitudeDelta(meters: selectedMeterRadius)
                                    print("Searching \(selectedMeterRadius) (\(searchRadius) lat delta)")
                                    Task {
                                        await search(for: currentSearchTerm!)
                                        isLoading = false
                                    }
                                }
                            }
                            .onChange(of: selectedMeterRadius) {
                                if currentSearchTerm != nil {
                                    searchRadius = calculateLatitudeDelta(meters: selectedMeterRadius)
                                    print("Searching \(selectedMeterRadius) (\(searchRadius) lat delta)")
                                    Task {
                                        await search(for: currentSearchTerm!)
                                        isLoading = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func search(for query: String) async -> Void {
        if locationManager.location == nil {
            return
        }
        
        let searchCenter = locationManager.location!
        
        print("Searching: \(query) at \(searchCenter)")
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: searchCenter,
            span: MKCoordinateSpan(
                latitudeDelta: searchRadius,
                longitudeDelta: searchRadius
            )
        )
        
        let latRange = (searchCenter.latitude - searchRadius)...(searchCenter.latitude + searchRadius)
        let lonRange = (searchCenter.longitude - searchRadius)...(searchCenter.longitude + searchRadius)
        
        Task {
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()
            
            let resultsInRange = response?.mapItems.filter {
                let itemLat = $0.placemark.coordinate.latitude
                let itemLon = $0.placemark.coordinate.longitude
                
                return latRange.contains(itemLat) && lonRange.contains(itemLon)
            }
            
            searchResults = resultsInRange ?? []
        }
    }

}

#Preview {
    LocationMap()
}
