import SwiftUI
import Supabase

// Uses the existing global `supabase` client declared in App.swift.

struct RealEmployee: Codable, Identifiable {
    let id: UUID
    let organizationId: UUID
    let fullName: String
    let department: String?
    let jobTitle: String?
    let salary: Double
    let email: String?
    let phone: String?
    let status: String
    enum CodingKeys: String, CodingKey {
        case id, department, salary, email, phone, status
        case organizationId = "organization_id"
        case fullName = "full_name"
        case jobTitle = "job_title"
    }
}

struct RealProduct: Codable, Identifiable {
    let id: UUID
    let organizationId: UUID
    let sku: String
    let name: String
    let category: String?
    let salePrice: Double
    let costPrice: Double
    let stock: Double
    let reorderLevel: Double
    let isActive: Bool
    enum CodingKeys: String, CodingKey {
        case id, sku, name, category, stock
        case organizationId = "organization_id"
        case salePrice = "sale_price"
        case costPrice = "cost_price"
        case reorderLevel = "reorder_level"
        case isActive = "is_active"
    }
}

struct RealInvoice: Codable, Identifiable {
    let id: UUID
    let organizationId: UUID
    let invoiceNo: String
    let partyName: String
    let subtotal: Double
    let tax: Double
    let total: Double
    let status: String
    let issuedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, subtotal, tax, total, status
        case organizationId = "organization_id"
        case invoiceNo = "invoice_no"
        case partyName = "party_name"
        case issuedAt = "issued_at"
    }
}

struct RealWarehouse: Codable, Identifiable {
    let id: UUID
    let organizationId: UUID
    let name: String
    let code: String
    let location: String?
    let isDefault: Bool
    enum CodingKeys: String, CodingKey {
        case id, name, code, location
        case organizationId = "organization_id"
        case isDefault = "is_default"
    }
}

struct RealOrg: Codable, Identifiable {
    let id: UUID
    let name: String
    let ownerId: UUID
    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "owner_id"
    }
}

struct RealInsertOrg: Encodable { let name: String; let currency: String; let owner_id: UUID }
struct RealInsertMember: Encodable { let organization_id: UUID; let user_id: UUID; let role: String }
struct RealInsertEmployee: Encodable {
    let organization_id: UUID; let full_name: String; let department: String?; let job_title: String?; let salary: Double; let email: String?; let phone: String?; let status: String
}
struct RealInsertProduct: Encodable {
    let organization_id: UUID; let sku: String; let name: String; let category: String?; let sale_price: Double; let cost_price: Double; let stock: Double; let reorder_level: Double; let is_active: Bool
}
struct RealInsertWarehouse: Encodable { let organization_id: UUID; let name: String; let code: String; let location: String?; let is_default: Bool }
struct RealInsertInvoice: Encodable { let organization_id: UUID; let invoice_no: String; let kind: String; let party_name: String; let subtotal: Double; let tax: Double; let total: Double; let status: String }

@MainActor
final class RealERPStore: ObservableObject {
    @Published var org: RealOrg?
    @Published var employees: [RealEmployee] = []
    @Published var products: [RealProduct] = []
    @Published var invoices: [RealInvoice] = []
    @Published var warehouses: [RealWarehouse] = []
    @Published var error = ""

    var revenue: Double { invoices.reduce(0) { $0 + $1.total } }
    var inventoryValue: Double { products.reduce(0) { $0 + ($1.costPrice * $1.stock) } }

    func bootstrap() async {
        do {
            let user = try await supabase.auth.user()
            let existing: [RealOrg] = try await supabase.from("erp_organizations").select().eq("owner_id", value: user.id.uuidString).limit(1).execute().value
            if let first = existing.first {
                org = first
            } else {
                let created: [RealOrg] = try await supabase.from("erp_organizations").insert(RealInsertOrg(name: "منشأتي", currency: "SAR", owner_id: user.id)).select().execute().value
                guard let first = created.first else { return }
                org = first
                try await supabase.from("erp_members").insert(RealInsertMember(organization_id: first.id, user_id: user.id, role: "owner")).execute()
                try await supabase.from("erp_warehouses").insert(RealInsertWarehouse(organization_id: first.id, name: "المخزن الرئيسي", code: "MAIN", location: nil, is_default: true)).execute()
            }
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    func refresh() async {
        guard let org else { return }
        do {
            async let e: [RealEmployee] = supabase.from("erp_employees").select().eq("organization_id", value: org.id.uuidString).order("full_name").execute().value
            async let p: [RealProduct] = supabase.from("erp_products").select().eq("organization_id", value: org.id.uuidString).order("name").execute().value
            async let i: [RealInvoice] = supabase.from("erp_invoices").select().eq("organization_id", value: org.id.uuidString).order("issued_at", ascending: false).execute().value
            async let w: [RealWarehouse] = supabase.from("erp_warehouses").select().eq("organization_id", value: org.id.uuidString).order("name").execute().value
            let r = try await (e,p,i,w)
            employees = r.0; products = r.1; invoices = r.2; warehouses = r.3; error = ""
        } catch { self.error = error.localizedDescription }
    }

    func addEmployee(name: String, department: String, title: String, salary: Double) async {
        guard let org else { return }
        do {
            try await supabase.from("erp_employees").insert(RealInsertEmployee(organization_id: org.id, full_name: name, department: department.isEmpty ? nil : department, job_title: title.isEmpty ? nil : title, salary: salary, email: nil, phone: nil, status: "active")).execute()
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    func addProduct(name: String, sku: String, sale: Double, cost: Double, stock: Double) async {
        guard let org else { return }
        do {
            try await supabase.from("erp_products").insert(RealInsertProduct(organization_id: org.id, sku: sku, name: name, category: nil, sale_price: sale, cost_price: cost, stock: stock, reorder_level: 5, is_active: true)).execute()
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    func addWarehouse(name: String, code: String) async {
        guard let org else { return }
        do {
            try await supabase.from("erp_warehouses").insert(RealInsertWarehouse(organization_id: org.id, name: name, code: code, location: nil, is_default: warehouses.isEmpty)).execute()
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    func completeSale(_ cart: [RealCartItem]) async {
        guard let org, !cart.isEmpty else { return }
        let subtotal = cart.reduce(0) { $0 + $1.subtotal }
        let tax = subtotal * 0.15
        do {
            try await supabase.from("erp_invoices").insert(RealInsertInvoice(organization_id: org.id, invoice_no: "INV-\(Int(Date().timeIntervalSince1970))", kind: "sale", party_name: "عميل نقدي", subtotal: subtotal, tax: tax, total: subtotal + tax, status: "paid")).execute()
            for line in cart {
                let newStock = max(0, line.product.stock - Double(line.quantity))
                try await supabase.from("erp_products").update(["stock": newStock]).eq("id", value: line.product.id.uuidString).execute()
            }
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
}

struct RealERPHome: View {
    @StateObject private var store = RealERPStore()
    var body: some View {
        TabView {
            NavigationStack { RealDashboard(store: store) }.tabItem { Label("الرئيسية", systemImage: "chart.bar.fill") }
            NavigationStack { RealPOS(store: store) }.tabItem { Label("POS", systemImage: "cart.fill") }
            NavigationStack { RealProducts(store: store) }.tabItem { Label("المخزون", systemImage: "shippingbox.fill") }
            NavigationStack { RealEmployees(store: store) }.tabItem { Label("الموظفون", systemImage: "person.3.fill") }
            NavigationStack { RealMore(store: store) }.tabItem { Label("المزيد", systemImage: "ellipsis") }
        }
        .task { if store.org == nil { await store.bootstrap() } }
        .overlay(alignment: .top) {
            if !store.error.isEmpty { Text(store.error).font(.caption).padding(8).background(.red, in: Capsule()).padding(.top, 6) }
        }
    }
}

struct RealDashboard: View {
    @ObservedObject var store: RealERPStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("لوحة التحكم").font(.largeTitle.bold())
                Text(store.org?.name ?? "جاري التحميل…").foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    RealMetric(title: "المبيعات", value: store.revenue)
                    RealMetric(title: "قيمة المخزون", value: store.inventoryValue)
                    RealCount(title: "الموظفون", count: store.employees.count)
                    RealCount(title: "المنتجات", count: store.products.count)
                }
                Text("آخر الفواتير").font(.headline)
                if store.invoices.isEmpty { ContentUnavailableView("لا توجد فواتير", systemImage: "doc.text") }
                else { ForEach(store.invoices.prefix(5)) { i in HStack { Text(i.partyName); Spacer(); Text(i.total, format: .currency(code: "SAR")) }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
            }.padding()
        }
    }
}

struct RealMetric: View { let title: String; let value: Double; var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value, format: .currency(code: "SAR")).font(.headline) }.padding().frame(maxWidth: .infinity, minHeight: 90, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
struct RealCount: View { let title: String; let count: Int; var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text("\(count)").font(.headline) }.padding().frame(maxWidth: .infinity, minHeight: 90, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16)) } }

struct RealEmployees: View {
    @ObservedObject var store: RealERPStore
    @State private var show = false
    var body: some View {
        Group {
            if store.employees.isEmpty { ContentUnavailableView("لا يوجد موظفون", systemImage: "person.3", description: Text("اضغط + لإضافة موظف")) }
            else { List(store.employees) { e in HStack { VStack(alignment: .leading) { Text(e.fullName).fontWeight(.semibold); Text([e.department,e.jobTitle].compactMap{$0}.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(e.salary, format: .currency(code: "SAR")) } } }
        }
        .navigationTitle("الموظفون")
        .toolbar { Button { show = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $show) { RealAddEmployee(store: store) }
        .refreshable { await store.refresh() }
    }
}

struct RealAddEmployee: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: RealERPStore
    @State var name = ""; @State var dept = ""; @State var title = ""; @State var salary = ""
    var body: some View { NavigationStack { Form { TextField("الاسم", text: $name); TextField("القسم", text: $dept); TextField("المسمى", text: $title); TextField("الراتب", text: $salary).keyboardType(.decimalPad) }.navigationTitle("موظف جديد").toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("حفظ") { Task { await store.addEmployee(name: name, department: dept, title: title, salary: Double(salary) ?? 0); if store.error.isEmpty { dismiss() } } }.disabled(name.isEmpty) } } } }
}

struct RealProducts: View {
    @ObservedObject var store: RealERPStore
    @State private var show = false
    var body: some View {
        Group {
            if store.products.isEmpty { ContentUnavailableView("لا توجد منتجات", systemImage: "shippingbox", description: Text("اضغط + لإضافة منتج")) }
            else { List(store.products) { p in HStack { VStack(alignment: .leading) { Text(p.name).fontWeight(.semibold); Text(p.sku).font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing) { Text(p.salePrice, format: .currency(code: "SAR")); Text("الكمية \(p.stock, specifier: "%.0f")").font(.caption) } } } }
        }
        .navigationTitle("المخزون")
        .toolbar { Button { show = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $show) { RealAddProduct(store: store) }
        .refreshable { await store.refresh() }
    }
}

struct RealAddProduct: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: RealERPStore
    @State var name = ""; @State var sku = ""; @State var sale = ""; @State var cost = ""; @State var stock = ""
    var body: some View { NavigationStack { Form { TextField("اسم المنتج", text: $name); TextField("SKU / الباركود", text: $sku); TextField("سعر البيع", text: $sale).keyboardType(.decimalPad); TextField("التكلفة", text: $cost).keyboardType(.decimalPad); TextField("الكمية", text: $stock).keyboardType(.decimalPad) }.navigationTitle("منتج جديد").toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("حفظ") { Task { await store.addProduct(name: name, sku: sku, sale: Double(sale) ?? 0, cost: Double(cost) ?? 0, stock: Double(stock) ?? 0); if store.error.isEmpty { dismiss() } } }.disabled(name.isEmpty || sku.isEmpty) } } } }
}

struct RealCartItem: Identifiable { var id: UUID { product.id }; let product: RealProduct; var quantity: Int; var subtotal: Double { product.salePrice * Double(quantity) } }
struct RealPOS: View {
    @ObservedObject var store: RealERPStore
    @State var cart: [RealCartItem] = []
    var subtotal: Double { cart.reduce(0) { $0 + $1.subtotal } }
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("المنتجات") { ForEach(store.products) { p in Button { add(p) } label: { HStack { Text(p.name).foregroundStyle(.primary); Spacer(); Text(p.salePrice, format: .currency(code: "SAR")) } }.disabled(p.stock <= 0) } }
                if !cart.isEmpty { Section("السلة") { ForEach(cart) { c in HStack { Text(c.product.name); Spacer(); Text("×\(c.quantity)"); Text(c.subtotal, format: .currency(code: "SAR")) } }.onDelete { cart.remove(atOffsets: $0) } } }
            }
            VStack { HStack { Text("قبل الضريبة"); Spacer(); Text(subtotal, format: .currency(code: "SAR")) }; HStack { Text("ضريبة 15%"); Spacer(); Text(subtotal * 0.15, format: .currency(code: "SAR")) }; HStack { Text("الإجمالي").bold(); Spacer(); Text(subtotal * 1.15, format: .currency(code: "SAR")).bold() }; Button("إتمام البيع") { Task { await store.completeSale(cart); if store.error.isEmpty { cart.removeAll() } } }.buttonStyle(.borderedProminent).disabled(cart.isEmpty) }.padding().background(.ultraThinMaterial)
        }.navigationTitle("POS")
    }
    func add(_ p: RealProduct) { if let i = cart.firstIndex(where: {$0.product.id == p.id}) { if Double(cart[i].quantity) < p.stock { cart[i].quantity += 1 } } else { cart.append(RealCartItem(product: p, quantity: 1)) } }
}

struct RealMore: View {
    @ObservedObject var store: RealERPStore
    @State private var showWarehouse = false
    var body: some View {
        List {
            Section("العمليات") { NavigationLink("المخازن") { RealWarehouses(store: store) }; NavigationLink("الفواتير") { RealInvoices(store: store) } }
            Section { Button("تسجيل الخروج", role: .destructive) { Task { try? await supabase.auth.signOut() } } }
        }.navigationTitle("المزيد")
    }
}

struct RealWarehouses: View {
    @ObservedObject var store: RealERPStore
    @State var show = false
    var body: some View { List(store.warehouses) { w in VStack(alignment: .leading) { Text(w.name).fontWeight(.semibold); Text(w.code).font(.caption).foregroundStyle(.secondary) } }.navigationTitle("المخازن").toolbar { Button { show = true } label: { Image(systemName: "plus") } }.sheet(isPresented: $show) { RealAddWarehouse(store: store) } }
}
struct RealAddWarehouse: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: RealERPStore
    @State var name = ""; @State var code = ""
    var body: some View { NavigationStack { Form { TextField("اسم المخزن", text: $name); TextField("الكود", text: $code) }.navigationTitle("مخزن جديد").toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("حفظ") { Task { await store.addWarehouse(name: name, code: code); if store.error.isEmpty { dismiss() } } }.disabled(name.isEmpty || code.isEmpty) } } } }
}
struct RealInvoices: View { @ObservedObject var store: RealERPStore; var body: some View { List(store.invoices) { i in HStack { VStack(alignment: .leading) { Text(i.partyName); Text(i.invoiceNo).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(i.total, format: .currency(code: "SAR")) } }.navigationTitle("الفواتير") } }
