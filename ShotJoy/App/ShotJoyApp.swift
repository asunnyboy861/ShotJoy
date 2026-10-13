import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct ShotJoyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var lockVisible = true

    private static let container: ModelContainer = {
        let schema = Schema([Compound.self, Vial.self, DoseLog.self, SymptomLog.self, MealLog.self, WeightEntry.self, GoalSettings.self])
        if FileManager.default.ubiquityIdentityToken != nil {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.zzoutuo.ShotJoy"))
            if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
                return container
            }
        }
        let local = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            return container
        }
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return (try? ModelContainer(for: schema, configurations: [memory]))!
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    if FaceIDService.isLockEnabled && lockVisible {
                        LockScreenView(isUnlocked: $isUnlocked, lockVisible: $lockVisible)
                    } else {
                        RootTabView()
                    }
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(Self.container)
            .tint(AppTheme.coral)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background && FaceIDService.isLockEnabled {
                    lockVisible = true
                    isUnlocked = false
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @Binding var lockVisible: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.coral)
            Text("ShotJoy is locked")
                .font(.title2.bold())
            Button {
                FaceIDService.authenticate { ok in
                    if ok {
                        isUnlocked = true
                        lockVisible = false
                    }
                }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.coral, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { FaceIDService.authenticate { ok in if ok { isUnlocked = true; lockVisible = false } } }
    }
}
