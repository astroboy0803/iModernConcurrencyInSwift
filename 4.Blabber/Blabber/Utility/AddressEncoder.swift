import Contacts
import CoreLocation

enum AddressEncoder {
    static func addressFor(location: CLLocation, completion: @escaping (String?, Error?) -> Void) {
        let geocoder = CLGeocoder()

        Task {
            do {
                guard
                    let placemark = try await geocoder.reverseGeocodeLocation(location).first,
                    let address = placemark.postalAddress
                else {
                    completion(nil, "No addresses found")
                    return
                }
                completion(CNPostalAddressFormatter.string(from: address, style: .mailingAddress), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
