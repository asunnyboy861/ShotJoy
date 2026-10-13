import Foundation
import LocalAuthentication

enum FaceIDService {
    static var isLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "appLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "appLockEnabled") }
    }

    static var biometricsAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    static func authenticate(completion: @escaping (Bool) -> Void) {
        guard isLockEnabled, biometricsAvailable else {
            completion(true)
            return
        }
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var evalError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evalError) else {
            completion(true)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your ShotJoy health records") { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
