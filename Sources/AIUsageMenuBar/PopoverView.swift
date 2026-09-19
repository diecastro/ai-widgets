import SwiftUI
import UsageCore

struct PopoverView: View {
    @Bindable var model: UsageModel
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.providers.enumerated()), id: \.element.provider) { index, snapshot in
                if index > 0 { Divider().padding(.vertical, 10) }
                providerSection(snapshot)
            }

            if model.providers.isEmpty { emptyState }

            Divider().padding(.top, 12)
            footer
        }
        .padding(14)
        .frame(width: UsageStyle.popoverWidth)
    }

    private func providerSection(_ snapshot: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(relativeAge(of: snapshot.observedAt, from: model.now))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if snapshot.windows.isEmpty {
                Text("No limits reported")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(snapshot.windows, id: \.kind) { window in
                    QuotaRowView(window: window,
                                 freshness: model.freshness(snapshot, window),
                                 now: model.now)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No usage data yet")
                .font(.system(size: 12, weight: .semibold))
            Text("Run Claude Code or Codex once and this fills in. Claude also needs the statusline hook installed.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Refresh") { Task { await model.refresh() } }
                .disabled(model.isRefreshing)
            Spacer()
            Button("Quit", action: onQuit)
        }
        .buttonStyle(.accessoryBar)
        .font(.system(size: 11))
        .padding(.top, 10)
    }
}
