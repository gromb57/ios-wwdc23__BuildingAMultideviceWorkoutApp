/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A SwiftUI view that shows the workout charts.
*/

import HealthKit
import SwiftUI
import Charts

struct LineChartEntry: Identifiable, Hashable {
    let category: String
    let date: Date
    let value: Double
    var id: Date {
        date
    }
}

struct ChartView: View {
    @Binding var workout: HKWorkout?
    @State private var speedEntries = [LineChartEntry]()
    @State private var powerEntries = [LineChartEntry]()
    @State private var cadenceEntries = [LineChartEntry]()
    /**
     Creates a stream that buffers a single newest element, and the stream's continuation to yield new elements synchronously to the stream.
     Use State to make sure the stream and continuation have the same life cycle of the view.
     */
    @State private var asynStreamTuple = AsyncStream.makeStream(of: HKWorkout.self, bufferingPolicy: .bufferingNewest(1))
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Spacer(minLength: 15)
                    GroupBox("Speed") {
                        Chart(speedEntries) { entry in
                            LineMark(
                                x: .value("Time", entry.date, unit: .minute),
                                y: .value("Speed", entry.value)
                            )
                            .symbol(by: .value("Speed", entry.category))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartLegend(.hidden)
                    }
                    Spacer(minLength: 15)
                }
                HStack {
                    Spacer(minLength: 15)
                    GroupBox("Power") {
                        Chart(powerEntries) { entry in
                            LineMark(
                                x: .value("Time", entry.date, unit: .minute),
                                y: .value("Power", entry.value)
                            )
                        }
                        .chartLegend(.hidden)
                    }
                    Spacer(minLength: 15)
                }
                HStack {
                    Spacer(minLength: 15)

                    GroupBox("Cadence") {
                        Chart(cadenceEntries) { entry in
                            LineMark(
                                x: .value("Time", entry.date, unit: .minute),
                                y: .value("Cadence", entry.value)
                            )
                        }
                        .chartLegend(.hidden)
                    }
                    Spacer(minLength: 15)

                }
                
                HStack {
                    Spacer(minLength: 15)
                    GroupBox("Summary") {
                        SummaryView(workout: $workout)
                    }
                    Spacer(minLength: 15)
                }
            }
            .task {
                /**
                 Consume the values asynchronously in this single task.
                 The next value in the stream can't start processing until "await updateLineEntries(for: value)" returns
                 and the loop enters the next iteration, which serializes the asynchronous operations.
                 */
                for await value in asynStreamTuple.stream {
                    await updateLineEntries(for: value)
                }
            }
            .onChange(of: workout) { _, newValue in
                if let newWorkout = newValue {
                    asynStreamTuple.continuation.yield(newWorkout)
                }
            }
        }
    }
    
    private func updateLineEntries(for streamedWorkout: HKWorkout) async {
        guard let workout = workout else {
            speedEntries = []
            powerEntries = []
            cadenceEntries = []
            return
        }
        let workoutManager = WorkoutManager.shared
        /**
         Fetching cycling speed statistics.
         */
        let speedStatisticsList = await workoutManager.fetchQuantityCollection(
            for: workout,
            quantityTypeIdentifier: .cyclingSpeed,
            statisticsOptions: .discreteAverage
        )
        speedEntries = speedStatisticsList.compactMap {
            if let speedValue = $0.averageQuantity()?.doubleValue(for: HKUnit.mile().unitDivided(by: HKUnit.hour())) {
                return LineChartEntry(category: "Speed", date: $0.endDate, value: speedValue)
            } else {
                return nil
            }
        }
        /**
         Fetching cycling power statistics.
         */
        let powerStatisticsList = await workoutManager.fetchQuantityCollection(
            for: workout,
            quantityTypeIdentifier: .cyclingPower,
            statisticsOptions: .discreteAverage
        )
        powerEntries = powerStatisticsList.compactMap {
            if let watt = $0.averageQuantity()?.doubleValue(for: .watt()) {
                return LineChartEntry(category: "Power", date: $0.endDate, value: watt)
            } else {
                return nil
            }
        }
        /**
         Fetching cycling cadence statistics.
         */
        let cadenceStatisticsList = await workoutManager.fetchQuantityCollection(
            for: workout,
            quantityTypeIdentifier: .cyclingCadence,
            statisticsOptions: .discreteAverage
        )
        cadenceEntries = cadenceStatisticsList.compactMap {
            let cadenceUnit = HKUnit.count().unitDivided(by: .minute())
            if let rpm = $0.averageQuantity()?.doubleValue(for: cadenceUnit) {
                return LineChartEntry(category: "Cadence", date: $0.endDate, value: rpm)
            } else {
                return nil
            }
        }
    }
}
