import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WanderWondersWidgetBundle: WidgetBundle {
    var body: some Widget {
        WanderLiveActivity()
    }
}

struct WanderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WanderActivityAttributes.self) { context in
            WanderLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(
                        timerInterval: context.state.startDate...(context.state.startDate.addingTimeInterval(3600)),
                        countsDown: false,
                        showsHours: false
                    )
                    .monospacedDigit()
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                    .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WanderMilestonesRow(state: context.state)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(
                    timerInterval: context.state.startDate...(context.state.startDate.addingTimeInterval(3600)),
                    countsDown: false,
                    showsHours: false
                )
                .monospacedDigit()
                .font(.caption.bold())
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct WanderLockScreenView: View {
    let state: WanderActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Wander in progress")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.8))
                    Spacer()
                    Text(
                        timerInterval: state.startDate...(state.startDate.addingTimeInterval(3600)),
                        countsDown: false,
                        showsHours: false
                    )
                    .monospacedDigit()
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                }
                ProgressView(
                    timerInterval: state.startDate...(state.startDate.addingTimeInterval(1800)),
                    countsDown: false
                )
                .tint(.orange)
                WanderMilestonesRow(state: state)
            }
        }
        .padding()
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                Image(systemName: "leaf.fill")
                    .rotationEffect(.degrees(30))
                    .foregroundStyle(Color(hue: 0.08, saturation: 0.8, brightness: 0.75))
                Image(systemName: "leaf.fill")
                    .rotationEffect(.degrees(-20))
                    .foregroundStyle(.orange)
                Image(systemName: "leaf.fill")
                    .rotationEffect(.degrees(10))
                    .foregroundStyle(Color(hue: 0.11, saturation: 0.6, brightness: 0.85))
            }
            .font(.system(size: 9))
            .opacity(0.55)
            .padding(.top, 6)
            .padding(.trailing, 10)
        }
        .activityBackgroundTint(Color(hue: 0.09, saturation: 0.12, brightness: 0.97))
    }
}

private struct WanderMilestonesRow: View {
    let state: WanderActivityAttributes.ContentState

    var body: some View {
        HStack {
            WanderMilestoneView(minute: 10, awarded: state.tier10Awarded)
            Spacer()
            WanderMilestoneView(minute: 20, awarded: state.tier20Awarded)
            Spacer()
            WanderMilestoneView(minute: 30, awarded: state.tier30Awarded)
        }
    }
}

private struct WanderMilestoneView: View {
    let minute: Int
    let awarded: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: awarded ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(awarded ? Color.orange : Color.secondary)
            Text("\(minute) min")
                .font(.caption)
                .foregroundStyle(awarded ? Color.primary : Color.secondary)
        }
    }
}
