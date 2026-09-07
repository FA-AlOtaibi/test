import SwiftUI
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hgwjverwrpzwyixkprqo.supabase.co")!,
    supabaseKey: "sb_publishable_uHay3RzUOZ1J59IqCxO_HA_WLokij3y"
)

@main
struct FahadERPApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

struct RootView: View {
    @State private var signedIn = false
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""

    var body: some View {
        Group {
            if signedIn { MainERPView() }
            else {
                ZStack {
                    LinearGradient(colors: [.black, Color(red: 0.04, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Spacer()
                        Image(systemName: "square.grid.3x3.fill").font(.system(size: 54)).foregroundStyle(.white)
                        Text("Fahad ERP").font(.largeTitle.bold())
                        Text("ERP Native للآيفون").foregroundStyle(.secondary)
                        TextField("البريد الإلكتروني", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        SecureField("كلمة المرور", text: $password).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.secondary) }
                        Button("تسجيل الدخول") {
                            Task {
                                do {
                                    try await supabase.auth.signIn(email: email, password: password)
                                    signedIn = true
                                } catch { message = error.localizedDescription }
                            }
                        }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black).controlSize(.large)
                        Button("إنشاء حساب") {
                            Task {
                                do {
                                    _ = try await supabase.auth.signUp(email: email, password: password)
                                    message = "تم إنشاء الحساب"
                                } catch { message = error.localizedDescription }
                            }
                        }.foregroundStyle(.secondary)
                        Spacer()
                    }.padding(24)
                }
                .preferredColorScheme(.dark)
                .task {
                    if (try? await supabase.auth.session) != nil { signedIn = true }
                }
            }
        }
    }
}

struct MainERPView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }.tabItem { Label("الرئيسية", systemImage: "chart.bar") }
            NavigationStack { POSView() }.tabItem { Label("POS", systemImage: "cart.fill") }
            NavigationStack { InventoryView() }.tabItem { Label("المخزون", systemImage: "shippingbox.fill") }
            NavigationStack { HRView() }.tabItem { Label("الموظفون", systemImage: "person.3.fill") }
            NavigationStack { MoreView() }.tabItem { Label("المزيد", systemImage: "ellipsis") }
        }.preferredColorScheme(.dark)
    }
}

struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("لوحة التحكم").font(.largeTitle.bold())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    MetricCard(title: "المبيعات", value: "0 ر.س", icon: "arrow.up.right")
                    MetricCard(title: "المصروفات", value: "0 ر.س", icon: "arrow.down.right")
                    MetricCard(title: "المخزون", value: "0 ر.س", icon: "shippingbox")
                    MetricCard(title: "الموظفون", value: "0", icon: "person.2")
                }
                SectionCard(title: "تنبيهات", items: ["أصناف قاربت على النفاد", "فواتير تحتاج متابعة", "أوامر شراء مفتوحة"])
            }.padding()
        }
    }
}

struct MetricCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }.padding().frame(maxWidth: .infinity, minHeight: 120, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SectionCard: View {
    let title: String; let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { Label($0, systemImage: "circle.fill").font(.subheadline) }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct POSProduct: Identifiable { let id = UUID(); let name: String; let sku: String; let price: Double }
struct CartLine: Identifiable { let id = UUID(); let product: POSProduct; var quantity: Int }

struct POSView: View {
    @State private var cart: [CartLine] = []
    @State private var search = ""
    let products = [POSProduct(name: "منتج تجريبي A", sku: "1001", price: 120), POSProduct(name: "منتج تجريبي B", sku: "1002", price: 85)]
    var subtotal: Double { cart.reduce(0) { $0 + $1.product.price * Double($1.quantity) } }
    var tax: Double { subtotal * 0.15 }
    var total: Double { subtotal + tax }
    var body: some View {
        VStack(spacing: 0) {
            List {
                TextField("بحث / SKU / باركود", text: $search)
                Section("المنتجات") {
                    ForEach(products.filter { search.isEmpty || $0.name.contains(search) || $0.sku.contains(search) }) { p in
                        Button { add(p) } label: { HStack { VStack(alignment: .leading) { Text(p.name); Text(p.sku).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(p.price, format: .currency(code: "SAR")) } }
                    }
                }
                if !cart.isEmpty {
                    Section("السلة") { ForEach(cart) { l in HStack { Text(l.product.name); Spacer(); Text("×\(l.quantity)"); Text(l.product.price * Double(l.quantity), format: .currency(code: "SAR")) } } }
                }
            }
            VStack(spacing: 6) {
                HStack { Text("قبل الضريبة"); Spacer(); Text(subtotal, format: .currency(code: "SAR")) }
                HStack { Text("ضريبة 15%"); Spacer(); Text(tax, format: .currency(code: "SAR")) }
                HStack { Text("الإجمالي").bold(); Spacer(); Text(total, format: .currency(code: "SAR")).bold() }
                Button("إتمام البيع") { cart.removeAll() }.buttonStyle(.borderedProminent).disabled(cart.isEmpty)
            }.padding().background(.ultraThinMaterial)
        }.navigationTitle("نقطة البيع")
    }
    func add(_ p: POSProduct) {
        if let i = cart.firstIndex(where: { $0.product.id == p.id }) { cart[i].quantity += 1 } else { cart.append(CartLine(product: p, quantity: 1)) }
    }
}

struct InventoryView: View {
    var body: some View {
        List {
            NavigationLink("المنتجات") { GenericList(title: "المنتجات", rows: ["SKU", "الكمية", "سعر البيع", "حد إعادة الطلب"]) }
            NavigationLink("المخازن المتعددة") { GenericList(title: "المخازن", rows: ["المخزن الرئيسي", "المخزن الفرعي", "تحويل بين المخازن"]) }
            NavigationLink("حركات المخزون") { GenericList(title: "الحركات", rows: ["بيع", "شراء", "تسوية", "تحويل داخلي"]) }
            NavigationLink("أوامر الشراء") { GenericList(title: "أوامر الشراء", rows: ["مسودة", "معتمد", "مستلم", "ملغي"]) }
        }.navigationTitle("المخزون")
    }
}

struct HRView: View {
    var body: some View {
        List {
            NavigationLink("الموظفون") { GenericList(title: "الموظفون", rows: ["الاسم", "القسم", "المسمى", "الراتب"]) }
            NavigationLink("الحضور والانصراف") { AttendanceView() }
            NavigationLink("الرواتب") { GenericList(title: "الرواتب", rows: ["الراتب الأساسي", "البدلات", "الخصومات", "الصافي"]) }
        }.navigationTitle("الموارد البشرية")
    }
}

struct AttendanceView: View {
    @State private var checkedIn = false
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: checkedIn ? "checkmark.circle.fill" : "clock").font(.system(size: 72))
            Text(checkedIn ? "تم تسجيل الحضور" : "لم يتم تسجيل الحضور").font(.title2.bold())
            Button(checkedIn ? "تسجيل الانصراف" : "تسجيل الحضور") { checkedIn.toggle() }.buttonStyle(.borderedProminent).controlSize(.large)
        }.navigationTitle("الحضور").frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MoreView: View {
    var body: some View {
        List {
            Section("المالية") {
                NavigationLink("الفواتير") { GenericList(title: "الفواتير", rows: ["مبيعات", "مشتريات", "ضريبة 15%", "تصدير PDF"]) }
                NavigationLink("المصروفات") { GenericList(title: "المصروفات", rows: ["تشغيل", "رواتب", "مشتريات", "أخرى"]) }
                NavigationLink("التقارير") { DashboardView() }
            }
            Section("الإدارة") {
                NavigationLink("العملاء والموردون") { GenericList(title: "الأطراف", rows: ["العملاء", "الموردون"]) }
                NavigationLink("الصلاحيات") { GenericList(title: "الصلاحيات", rows: ["Owner", "Admin", "Manager", "Accountant", "Sales", "Warehouse", "Viewer"]) }
                NavigationLink("Audit Log") { GenericList(title: "سجل العمليات", rows: ["إنشاء", "تعديل", "حذف", "اعتماد"]) }
            }
            Section { Button("تسجيل الخروج", role: .destructive) { Task { try? await supabase.auth.signOut() } } }
        }.navigationTitle("المزيد")
    }
}

struct GenericList: View {
    let title: String; let rows: [String]
    var body: some View { List(rows, id: \.self) { Label($0, systemImage: "checkmark.circle") }.navigationTitle(title) }
}
