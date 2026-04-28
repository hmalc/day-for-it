import SwiftUI

struct DriverListView: View {
    let drivers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top drivers")
                .font(.headline)
            if drivers.isEmpty {
                Text("No major drag factors detected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(drivers, id: \.self) { driver in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .padding(.top, 7)
                            .foregroundStyle(.secondary)
                        Text(driver)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}
