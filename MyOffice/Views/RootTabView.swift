import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack {
                OrgChartView()
            }
            .tabItem {
                Label(Strings.t(.tabOrg, app.lang), systemImage: "person.3.sequence")
            }

            NavigationStack {
                PeopleListView()
            }
            .tabItem {
                Label(Strings.t(.tabPeople, app.lang), systemImage: "person.text.rectangle")
            }

            NavigationStack {
                ExportView()
            }
            .tabItem {
                Label(Strings.t(.tabExport, app.lang), systemImage: "square.and.arrow.up")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(Strings.t(.tabSettings, app.lang), systemImage: "gearshape")
            }
        }
        .tint(app.theme.accent)
        .overlay(alignment: .bottom) {
            if let message = app.toastMessage {
                ToastView(text: message)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation { app.toastMessage = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.toastMessage)
        .sheet(isPresented: Binding(
            get: { app.upsellContext != nil },
            set: { newValue in if !newValue { app.upsellContext = nil } }
        )) {
            if let context = app.upsellContext {
                LimitPaywallSheet(context: context)
            }
        }
    }
}

private struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .shadow(radius: 4)
    }
}
