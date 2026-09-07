import SwiftUI
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hgwjverwrpzwyixkprqo.supabase.co")!,
    supabaseKey: "sb_publishable_uHay3RzUOZ1J59IqCxO_HA_WLokij3y"
)

@main
struct FahadERPApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var signedIn = false
    @State private var checking = true
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""

    var body: some View {
        Group {
            if checking {
                ProgressView("جاري التحقق…")
                    .preferredColorScheme(.dark)
            } else if signedIn {
                RealERPHome()
            } else {
                ZStack {
                    LinearGradient(colors: [.black, Color(red: 0.04, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 18) {
                            Spacer(minLength: 80)
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 54))
                            Text("Fahad ERP").font(.largeTitle.bold())
                            Text("ERP فعلي مرتبط بقاعدة البيانات").foregroundStyle(.secondary)

                            TextField("البريد الإلكتروني", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            SecureField("كلمة المرور", text: $password)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                            if !message.isEmpty {
                                Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
                            }

                            Button("تسجيل الدخول") {
                                guard validate() else { return }
                                Task {
                                    do {
                                        try await supabase.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                        signedIn = true
                                        message = ""
                                    } catch {
                                        message = "تعذر تسجيل الدخول: \(error.localizedDescription)"
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(.black)
                            .controlSize(.large)

                            Button("إنشاء حساب") {
                                guard validate() else { return }
                                Task {
                                    do {
                                        let result = try await supabase.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                        if result.session != nil {
                                            signedIn = true
                                            message = ""
                                        } else {
                                            message = "تم إنشاء الحساب. أكّد بريدك الإلكتروني ثم سجّل الدخول."
                                        }
                                    } catch {
                                        message = "تعذر إنشاء الحساب: \(error.localizedDescription)"
                                    }
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(24)
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .task {
            if (try? await supabase.auth.session) != nil { signedIn = true }
            checking = false
        }
    }

    private func validate() -> Bool {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { message = "أدخل البريد الإلكتروني."; return false }
        guard clean.contains("@") && clean.contains(".") else { message = "صيغة البريد الإلكتروني غير صحيحة."; return false }
        guard password.count >= 6 else { message = "كلمة المرور يجب أن تكون 6 أحرف على الأقل."; return false }
        return true
    }
}
