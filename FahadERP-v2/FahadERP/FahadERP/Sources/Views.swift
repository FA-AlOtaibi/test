import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ERPStore.self) private var store

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
                    .task {
                        if store.organization == nil { await store.bootstrap() }
                    }
            } else {
                LoginView()
            }
        }
    }
}

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        @Bindable var auth = auth
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.05, green: 0.09, blue: 0.13)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Fahad ERP").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("إدارة شركتك من مكان واحد").foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    TextField("البريد الإلكتروني", text: $auth.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    SecureField("كلمة المرور", text: $auth.password)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if let msg = auth.errorMessage {
                        Text(msg).font(.footnote).foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await auth.signIn() }
                    } label: {
                        HStack {
                            if auth.isLoading { ProgressView() }
                            Text("تسجيل الدخول").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)

                    Button("إنشاء حساب جديد") {
                        Task { await auth.signUp() }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("الرئيسية", systemImage: "chart.bar.xaxis") }
            NavigationStack { InventoryView() }
                .tabItem { Label("المخزون", systemImage: "shippingbox") }
            NavigationStack { POSView() }
                .tabItem { Label("POS", systemImage: "cart.fill") }
            NavigationStack { HRView() }
                .tabItem { Label("الموظفون", systemImage: "person.3") }
            NavigationStack { MoreView() }
                .tabItem { Label("المزيد", systemImage: "ellipsis") }
        }
    }
}

struct DashboardView: View {
    @Environment(ERPStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("لوحة التحكم").font(.largeTitle.bold())
                        Text(store.organization?.name ?? "...")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await store.refreshAll() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    MetricCard(title: "المبيعات", value: store.metrics.revenue, icon: "arrow.up.right")
                    MetricCard(title: "المصروفات", value: store.metrics.expenses, icon: "arrow.down.right")
                    MetricCard(title: "قيمة المخزون", value: store.metrics.stockValue, icon: "shippingbox.fill")
                    MetricCard(title: "الموظفون", valueText: "\(store.metrics.employees)", icon: "person.2.fill")
                }

                if store.metrics.lowStock > 0 {
                    Label("تنبيه: \(store.metrics.lowStock) أصناف وصلت لحد إعادة الطلب", systemImage: "exclamationmark.triangle.fill")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }

                SectionTitle("آخر الفواتير")
                ForEach(store.invoices.prefix(5)) { invoice in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(invoice.partyName).fontWeight(.semibold)
                            Text(invoice.invoiceNo).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(invoice.total, format: .currency(code: "SAR"))
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MetricCard: View {
    let title: String
    var value: Double? = nil
    var valueText: String? = nil
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                Spacer()
            }
            .foregroundStyle(.secondary)
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let value {
                Text(value, format: .currency(code: "SAR")).font(.title3.bold())
            } else {
                Text(valueText ?? "0").font(.title3.bold())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).font(.headline).padding(.top, 4) }
}

struct InventoryView: View {
    @Environment(ERPStore.self) private var store
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.products) { p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(p.name).fontWeight(.semibold)
                        Text("\(p.sku) • \(p.category ?? \"بدون تصنيف\")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(p.salePrice, format: .currency(code: "SAR"))
                        Text("المخزون \(p.stock, specifier: \"%.0f\")")
                            .font(.caption)
                            .foregroundStyle(p.stock <= p.reorderLevel ? .orange : .secondary)
                    }
                }
            }
        }
        .navigationTitle("المخزون")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) { AddProductView() }
    }
}

struct AddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ERPStore.self) private var store
    @State private var name = ""
    @State private var sku = ""
    @State private var price = ""
    @State private var cost = ""
    @State private var stock = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("اسم المنتج", text: $name)
                TextField("SKU", text: $sku)
                TextField("سعر البيع", text: $price).keyboardType(.decimalPad)
                TextField("التكلفة", text: $cost).keyboardType(.decimalPad)
                TextField("الكمية", text: $stock).keyboardType(.decimalPad)
            }
            .navigationTitle("منتج جديد")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        Task {
                            await store.addProduct(
                                name: name,
                                sku: sku,
                                price: Double(price) ?? 0,
                                cost: Double(cost) ?? 0,
                                stock: Double(stock) ?? 0
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || sku.isEmpty)
                }
            }
        }
    }
}

struct FinanceView: View {
    @Environment(ERPStore.self) private var store
    var body: some View {
        List {
            Section("الفواتير") {
                ForEach(store.invoices) { invoice in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(invoice.partyName)
                            Text(invoice.invoiceNo).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(invoice.total, format: .currency(code: "SAR"))
                    }
                }
            }
            Section("المصروفات") {
                ForEach(store.expenses) { expense in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(expense.title)
                            Text(expense.category ?? "عام").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(expense.amount, format: .currency(code: "SAR"))
                    }
                }
            }
        }
        .navigationTitle("المالية")
    }
}

struct HRView: View {
    @Environment(ERPStore.self) private var store
    var body: some View {
        List(store.employees) { employee in
            HStack {
                Image(systemName: "person.crop.circle.fill").font(.title2)
                VStack(alignment: .leading) {
                    Text(employee.fullName).fontWeight(.semibold)
                    Text(employee.jobTitle ?? employee.department ?? "موظف")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(employee.status == "active" ? "نشط" : employee.status)
                    .font(.caption)
            }
        }
        .navigationTitle("الموظفون")
    }
}

struct MoreView: View {
    @Environment(AuthViewModel.self) private var auth
    var body: some View {
        List {
            Section("العمليات") {
                NavigationLink { POSView() } label: { Label("نقطة البيع POS", systemImage: "cart") }
                NavigationLink { WarehousesView() } label: { Label("المخازن", systemImage: "building.2") }
                NavigationLink { PurchaseOrdersView() } label: { Label("أوامر الشراء", systemImage: "doc.text") }
            }
            Section("الموارد البشرية") {
                NavigationLink { AttendanceView() } label: { Label("الحضور والانصراف", systemImage: "clock.badge.checkmark") }
                NavigationLink { PayrollView() } label: { Label("الرواتب", systemImage: "banknote.fill") }
            }
            Section("الإدارة") {
                Label("العملاء", systemImage: "person.2")
                Label("الموردون", systemImage: "truck.box")
                NavigationLink { ReportsView() } label: { Label("التقارير", systemImage: "chart.pie") }
                NavigationLink { AuditLogView() } label: { Label("سجل العمليات", systemImage: "list.bullet.rectangle") }
                Label("الصلاحيات", systemImage: "lock.shield")
            }
            Section {
                Button(role: .destructive) {
                    Task { await auth.signOut() }
                } label: {
                    Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("المزيد")
    }
}
