import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var isAuthenticated = false

    private let client = SupabaseConfig.client

    init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        do {
            _ = try await client.auth.session
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "أدخل البريد الإلكتروني وكلمة المرور"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.auth.signIn(email: email, password: password)
            isAuthenticated = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "أدخل البريد الإلكتروني وكلمة المرور"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            errorMessage = "تم إنشاء الحساب. تحقق من البريد إذا كان التأكيد مفعلاً."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do { try await client.auth.signOut() } catch { }
        isAuthenticated = false
    }
}
