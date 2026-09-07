import SwiftUI
import UIKit

struct POSView: View {
    @Environment(ERPStore.self) private var store
    @State private var cart: [POSCartItem] = []
    @State private var customerName = ""
    @State private var search = ""
    @State private var showingCheckout = false
    @State private var errorText: String?

    var filtered: [ERPProduct] {
        if search.isEmpty { return store.products.filter(\.isActive) }
        return store.products.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.sku.localizedCaseInsensitiveContains(search)
        }
    }

    var subtotal: Double { cart.reduce(0) { $0 + $1.lineSubtotal } }
    var tax: Double { cart.reduce(0) { $0 + $1.tax } }
    var total: Double { subtotal + tax }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    TextField("بحث بالاسم أو الباركود / SKU", text: $search)
                }
                Section("المنتجات") {
                    ForEach(filtered) { product in
                        Button { add(product) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(product.name).foregroundStyle(.primary)
                                    Text("\(product.sku) • متوفر \(product.stock, specifier: \"%.0f\")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(product.salePrice, format: .currency(code: "SAR"))
                            }
                        }
                        .disabled(product.stock <= 0)
                    }
                }
                if !cart.isEmpty {
                    Section("السلة") {
                        ForEach(cart) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.product.name)
                                    Text("× \(item.quantity, specifier: \"%.0f\")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.lineTotal, format: .currency(code: "SAR"))
                            }
                        }
                        .onDelete { idx in cart.remove(atOffsets: idx) }
                    }
                }
            }
            if !cart.isEmpty {
                VStack(spacing: 8) {
                    HStack { Text("قبل الضريبة"); Spacer(); Text(subtotal, format: .currency(code: "SAR")) }
                    HStack { Text("ضريبة 15%"); Spacer(); Text(tax, format: .currency(code: "SAR")) }
                    HStack { Text("الإجمالي").fontWeight(.bold); Spacer(); Text(total, format: .currency(code: "SAR")).fontWeight(.bold) }
                    Button("إتمام البيع") { showingCheckout = true }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("نقطة البيع")
        .sheet(isPresented: $showingCheckout) {
            NavigationStack {
                Form {
                    TextField("اسم العميل - اختياري", text: $customerName)
                    LabeledContent("الإجمالي") {
                        Text(total, format: .currency(code: "SAR")).fontWeight(.bold)
                    }
                    if let errorText { Text(errorText).foregroundStyle(.red) }
                }
                .navigationTitle("تأكيد العملية")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { showingCheckout = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("تحصيل") {
                            Task {
                                do {
                                    try await store.createSale(from: cart, customerName: customerName)
                                    cart.removeAll()
                                    showingCheckout = false
                                } catch {
                                    errorText = error.localizedDescription
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func add(_ product: ERPProduct) {
        if let i = cart.firstIndex(where: { $0.product.id == product.id }) {
            if cart[i].quantity < product.stock { cart[i].quantity += 1 }
        } else {
            cart.append(POSCartItem(product: product, quantity: 1))
        }
    }
}

struct WarehousesView: View {
    @Environment(ERPStore.self) private var store
    @State private var showAdd = false
    var body: some View {
        List {
            ForEach(store.warehouses) { warehouse in
                VStack(alignment: .leading) {
                    HStack {
                        Text(warehouse.name).fontWeight(.semibold)
                        if warehouse.isDefault { Text("افتراضي").font(.caption).padding(5).background(.thinMaterial, in: Capsule()) }
                    }
                    Text("\(warehouse.code) • \(warehouse.location ?? \"بدون موقع\")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("المخازن")
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAdd) { AddWarehouseView() }
    }
}

struct AddWarehouseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ERPStore.self) private var store
    @State private var name = ""
    @State private var code = ""
    @State private var location = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("اسم المخزن", text: $name)
                TextField("الكود", text: $code)
                TextField("الموقع", text: $location)
            }
            .navigationTitle("مخزن جديد")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        Task { await store.addWarehouse(name: name, code: code, location: location); dismiss() }
                    }.disabled(name.isEmpty || code.isEmpty)
                }
            }
        }
    }
}

struct PurchaseOrdersView: View {
    @Environment(ERPStore.self) private var store
    @State private var showAdd = false
    var body: some View {
        List {
            ForEach(store.purchaseOrders) { po in
                HStack {
                    VStack(alignment: .leading) {
                        Text(po.supplierName).fontWeight(.semibold)
                        Text("\(po.poNumber) • \(po.status)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(po.total, format: .currency(code: "SAR"))
                }
            }
        }
        .navigationTitle("أوامر الشراء")
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAdd) { AddPOView() }
    }
}

struct AddPOView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ERPStore.self) private var store
    @State private var supplier = ""
    @State private var subtotal = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("المورد", text: $supplier)
                TextField("القيمة قبل الضريبة", text: $subtotal).keyboardType(.decimalPad)
                LabeledContent("الضريبة") { Text((Double(subtotal) ?? 0) * 0.15, format: .currency(code: "SAR")) }
                LabeledContent("الإجمالي") { Text((Double(subtotal) ?? 0) * 1.15, format: .currency(code: "SAR")) }
            }
            .navigationTitle("أمر شراء")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("إنشاء") {
                        Task { await store.createPurchaseOrder(supplier: supplier, subtotal: Double(subtotal) ?? 0); dismiss() }
                    }.disabled(supplier.isEmpty)
                }
            }
        }
    }
}

struct AttendanceView: View {
    @Environment(ERPStore.self) private var store
    var body: some View {
        List {
            ForEach(store.employees) { employee in
                VStack(alignment: .leading, spacing: 8) {
                    Text(employee.fullName).fontWeight(.semibold)
                    HStack {
                        Button("دخول") { Task { await store.clock(employee: employee, isIn: true) } }
                            .buttonStyle(.borderedProminent)
                        Button("خروج") { Task { await store.clock(employee: employee, isIn: false) } }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("الحضور")
    }
}

struct PayrollView: View {
    @Environment(ERPStore.self) private var store
    private var period: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: Date())
    }
    var body: some View {
        List {
            Section("إنشاء مسير \(period)") {
                ForEach(store.employees) { e in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(e.fullName)
                            Text(e.salary, format: .currency(code: "SAR")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("إنشاء") { Task { await store.generatePayroll(employee: e, period: period) } }
                    }
                }
            }
            Section("المسيرات") {
                ForEach(store.payroll) { p in
                    HStack {
                        Text(p.period)
                        Spacer()
                        Text(p.netSalary, format: .currency(code: "SAR"))
                    }
                }
            }
        }
        .navigationTitle("الرواتب")
    }
}

struct AuditLogView: View {
    @Environment(ERPStore.self) private var store
    var body: some View {
        List(store.auditLog) { log in
            VStack(alignment: .leading) {
                Text("\(log.action) • \(log.entity)").fontWeight(.semibold)
                if let date = log.createdAt {
                    Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("سجل العمليات")
    }
}

struct ReportsView: View {
    @Environment(ERPStore.self) private var store
    var grossProfit: Double {
        let cost = store.products.reduce(0) { $0 + ($1.costPrice * max(0, $1.stock)) }
        return store.metrics.revenue - store.metrics.expenses - cost
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MetricCard(title: "الإيرادات", value: store.metrics.revenue, icon: "chart.line.uptrend.xyaxis")
                MetricCard(title: "المصروفات", value: store.metrics.expenses, icon: "chart.line.downtrend.xyaxis")
                MetricCard(title: "قيمة المخزون", value: store.metrics.stockValue, icon: "shippingbox")
                MetricCard(title: "صافي تقريبي", value: grossProfit, icon: "sum")
            }
            .padding()
        }
        .navigationTitle("التقارير")
    }
}
