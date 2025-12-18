import WidgetKit
import SwiftUI

// 1. Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), bulbs: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), bulbs: BulbStore().bulbs.filter { $0.showInWidget })
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Re-initialize the store to force a fresh load from the App Group
        let store = BulbStore()
        let bulbs = store.bulbs.filter { $0.showInWidget }
        
        // Debugging Logs: These appear in the Console if you debug the Widget Scheme
        print("Widget: Reload requested.")
        print("Widget: Found \(bulbs.count) bulbs to show.")
        if let first = bulbs.first {
            print("Widget: \(first.name) is \(first.isVerifiedOn ? "ON" : "OFF")")
        }
        
        let entry = SimpleEntry(date: Date(), bulbs: bulbs)
        
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// 2. The Data Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let bulbs: [Bulb]
}

// 3. The Widget View
struct WiZWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 0) {
            let bulbsToShow = Array(entry.bulbs.prefix(2))
            
            if bulbsToShow.isEmpty {
                VStack {
                    Text("No Bulbs Selected")
                        .font(.headline)
                        .fontDesign(.rounded)
                    Text("Check Settings in Main App")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(bulbsToShow) { bulb in
                    BulbView(bulb: bulb)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if bulb.id != bulbsToShow.last?.id {
                        Divider()
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// 4. Individual Bulb View
struct BulbView: View {
    let bulb: Bulb
    
    var body: some View {
        VStack {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 24))
                .foregroundColor(bulb.isVerifiedOn ? bulb.displayColor : .gray.opacity(0.3))
                .shadow(color: bulb.isVerifiedOn ? bulb.displayColor : .clear, radius: 8)
                .scaleEffect(bulb.isVerifiedOn ? 1.1 : 1.0)
            
            Text(bulb.name)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .padding(.top, 6)
            
            Text(bulb.isVerifiedOn ? "On" : "Off")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// 5. The Widget Configuration
@main
struct WiZWidget: Widget {
    let kind: String = "WiZWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WiZWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("WiZ Status")
        .description("Shows status of selected bulbs.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
