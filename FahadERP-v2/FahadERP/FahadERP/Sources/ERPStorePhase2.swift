import Foundation
import Supabase

extension ERPStore {
    func loadPhase2() async {
        guard let org = organization else { return }
        do {
            async let w: [ERPWarehouse] = client.from("erp_warehouses").select().eq("organization_id", value: org.id.uuidString).order("name").execute().value
            async let po: [ERPPurchaseOrder] = client.from("erp_purchase_orders").select().eq("organization_id", value: org.id.uuidString).order("created_at", ascending: false).execute().value
            async let a: [ERPAttendance] = client.from("erp_attendance").select().eq("organization_id", value: org.id.uuidString).order("work_date", ascending: false).limit(100).execute().value
            async let pr: [ERPPayroll] = client.from("erp_payroll").select().eq("organization_id", value: org.id.uuidString).order("period", ascending: false).execute().value
            async let al: [ERPAuditLog] = client.from("erp_audit_log").select().eq("organization_id", value: org.id.uuidString).order("created_at", ascending: false).limit(100).execute().value

            let (warehouses, purchaseOrders, attendance, payroll, audit) = try await (w, po, a, pr, al)
            self.warehouses = warehouses
            self.purchaseOrders = purchaseOrders
            self.attendance = attendance
            self.payroll = payroll
            self.auditLog = audit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSale(from cart: [POSCartItem], customerName: String) async throws {
        guard let org = organization, !cart.isEmpty else { return }
        let subtotal = cart.reduce(0) { $0 + $1.lineSubtotal }
        let tax = cart.reduce(0) { $0 + $1.tax }
        let total = subtotal + tax
        let invoiceNo = "INV-\(Int(Date().timeIntervalSince1970))"

        let payload: [String: AnyJSON] = [
            "organization_id": .string(org.id.uuidString),
            "invoice_no": .string(invoiceNo),
            "kind": .string("sale"),
            "party_name": .string(customerName.isEmpty ? "عميل نقدي" : customerName),
            "subtotal": .double(subtotal),
            "tax": .double(tax),
            "total": .double(total),
            "status": .string("paid")
        ]
        try await client.from("erp_invoices").insert(payload).execute()

        for item in cart {
            let movement: [String: AnyJSON] = [
                "organization_id": .string(org.id.uuidString),
                "warehouse_id": .string((warehouses.first?.id ?? UUID()).uuidString),
                "product_id": .string(item.product.id.uuidString),
                "movement_type": .string("sale"),
                "quantity": .double(-item.quantity),
                "reference": .string(invoiceNo)
            ]
            if warehouses.first != nil {
                try await client.from("erp_stock_movements").insert(movement).execute()
            }
            let newStock = max(0, item.product.stock - item.quantity)
            try await client.from("erp_products")
                .update(["stock": newStock])
                .eq("id", value: item.product.id.uuidString)
                .execute()
        }

        await log(action: "create", entity: "sale_invoice", entityId: nil, note: invoiceNo)
        await refreshAll()
        await loadPhase2()
    }

    func addWarehouse(name: String, code: String, location: String) async {
        guard let org = organization else { return }
        do {
            let payload: [String: AnyJSON] = [
                "organization_id": .string(org.id.uuidString),
                "name": .string(name),
                "code": .string(code),
                "location": .string(location),
                "is_default": .bool(warehouses.isEmpty)
            ]
            try await client.from("erp_warehouses").insert(payload).execute()
            await loadPhase2()
        } catch { errorMessage = error.localizedDescription }
    }

    func createPurchaseOrder(supplier: String, subtotal: Double) async {
        guard let org = organization else { return }
        do {
            let tax = subtotal * 0.15
            let payload: [String: AnyJSON] = [
                "organization_id": .string(org.id.uuidString),
                "po_number": .string("PO-\(Int(Date().timeIntervalSince1970))"),
                "supplier_name": .string(supplier),
                "status": .string("draft"),
                "subtotal": .double(subtotal),
                "tax": .double(tax),
                "total": .double(subtotal + tax)
            ]
            try await client.from("erp_purchase_orders").insert(payload).execute()
            await log(action: "create", entity: "purchase_order", entityId: nil, note: supplier)
            await loadPhase2()
        } catch { errorMessage = error.localizedDescription }
    }

    func clock(employee: ERPEmployee, isIn: Bool) async {
        guard let org = organization else { return }
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date = formatter.string(from: Date())
            if isIn {
                let payload: [String: AnyJSON] = [
                    "organization_id": .string(org.id.uuidString),
                    "employee_id": .string(employee.id.uuidString),
                    "work_date": .string(date),
                    "check_in": .string(ISO8601DateFormatter().string(from: Date())),
                    "status": .string("present")
                ]
                try await client.from("erp_attendance").insert(payload).execute()
            } else {
                try await client.from("erp_attendance")
                    .update(["check_out": ISO8601DateFormatter().string(from: Date())])
                    .eq("employee_id", value: employee.id.uuidString)
                    .eq("work_date", value: date)
                    .execute()
            }
            await loadPhase2()
        } catch { errorMessage = error.localizedDescription }
    }

    func generatePayroll(employee: ERPEmployee, period: String) async {
        guard let org = organization else { return }
        do {
            let payload: [String: AnyJSON] = [
                "organization_id": .string(org.id.uuidString),
                "employee_id": .string(employee.id.uuidString),
                "period": .string(period),
                "base_salary": .double(employee.salary),
                "allowances": .double(0),
                "deductions": .double(0),
                "net_salary": .double(employee.salary),
                "status": .string("draft")
            ]
            try await client.from("erp_payroll").insert(payload).execute()
            await loadPhase2()
        } catch { errorMessage = error.localizedDescription }
    }

    func log(action: String, entity: String, entityId: UUID?, note: String) async {
        guard let org = organization else { return }
        do {
            let user = try await client.auth.user()
            var payload: [String: AnyJSON] = [
                "organization_id": .string(org.id.uuidString),
                "actor_id": .string(user.id.uuidString),
                "action": .string(action),
                "entity": .string(entity),
                "payload": .object(["note": .string(note)])
            ]
            if let entityId { payload["entity_id"] = .string(entityId.uuidString) }
            try await client.from("erp_audit_log").insert(payload).execute()
        } catch { }
    }
}
