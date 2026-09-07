import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class ERPStore {
    var organization: Organization?
    var products: [ERPProduct] = []
    var employees: [ERPEmployee] = []
    var invoices: [ERPInvoice] = []
    var expenses: [ERPExpense] = []
    var metrics = DashboardMetrics()

    var warehouses: [ERPWarehouse] = []
    var purchaseOrders: [ERPPurchaseOrder] = []
    var attendance: [ERPAttendance] = []
    var payroll: [ERPPayroll] = []
    var auditLog: [ERPAuditLog] = []
    var isLoading = false
    var errorMessage: String?

    let client = SupabaseConfig.client

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await client.auth.user()
            let orgs: [Organization] = try await client
                .from("erp_organizations")
                .select()
                .eq("owner_id", value: user.id.uuidString)
                .limit(1)
                .execute()
                .value

            if let first = orgs.first {
                organization = first
            } else {
                let draft = [
                    "name": "منشأتي",
                    "currency": "SAR",
                    "owner_id": user.id.uuidString
                ]
                let created: [Organization] = try await client
                    .from("erp_organizations")
                    .insert(draft)
                    .select()
                    .execute()
                    .value
                organization = created.first
                if let org = organization {
                    let member = [
                        "organization_id": org.id.uuidString,
                        "user_id": user.id.uuidString,
                        "role": "owner"
                    ]
                    try await client.from("erp_members").insert(member).execute()
                }
            }
            await refreshAll()
            await loadPhase2()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAll() async {
        guard let org = organization else { return }
        do {
            async let p: [ERPProduct] = client.from("erp_products").select().eq("organization_id", value: org.id.uuidString).order("name").execute().value
            async let e: [ERPEmployee] = client.from("erp_employees").select().eq("organization_id", value: org.id.uuidString).order("full_name").execute().value
            async let i: [ERPInvoice] = client.from("erp_invoices").select().eq("organization_id", value: org.id.uuidString).order("issued_at", ascending: false).execute().value
            async let x: [ERPExpense] = client.from("erp_expenses").select().eq("organization_id", value: org.id.uuidString).order("occurred_at", ascending: false).execute().value

            let (products, employees, invoices, expenses) = try await (p, e, i, x)
            self.products = products
            self.employees = employees
            self.invoices = invoices
            self.expenses = expenses
            recalc()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recalc() {
        metrics.revenue = invoices.filter { $0.kind == "sale" && $0.status != "cancelled" }.reduce(0) { $0 + $1.total }
        metrics.expenses = expenses.reduce(0) { $0 + $1.amount }
        metrics.stockValue = products.reduce(0) { $0 + ($1.costPrice * $1.stock) }
        metrics.employees = employees.filter { $0.status == "active" }.count
        metrics.lowStock = products.filter { $0.stock <= $0.reorderLevel }.count
    }

    func addProduct(name: String, sku: String, price: Double, cost: Double, stock: Double) async {
        guard let org = organization else { return }
        do {
            let payload: [String: AnyJSON] = [
                "organization_id": .string(org.id.uuidString),
                "name": .string(name),
                "sku": .string(sku),
                "sale_price": .double(price),
                "cost_price": .double(cost),
                "stock": .double(stock),
                "reorder_level": .double(5),
                "is_active": .bool(true)
            ]
            try await client.from("erp_products").insert(payload).execute()
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
