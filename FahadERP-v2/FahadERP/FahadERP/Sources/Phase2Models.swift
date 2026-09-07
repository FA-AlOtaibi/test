import Foundation

struct ERPWarehouse: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var name: String
    var code: String
    var location: String?
    var isDefault: Bool
    enum CodingKeys: String, CodingKey {
        case id, name, code, location
        case organizationId = "organization_id"
        case isDefault = "is_default"
    }
}

struct ERPStockMovement: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    let warehouseId: UUID
    let productId: UUID
    var movementType: String
    var quantity: Double
    var reference: String?
    var notes: String?
    var createdAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, quantity, reference, notes
        case organizationId = "organization_id"
        case warehouseId = "warehouse_id"
        case productId = "product_id"
        case movementType = "movement_type"
        case createdAt = "created_at"
    }
}

struct ERPPurchaseOrder: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var poNumber: String
    var supplierName: String
    var status: String
    var subtotal: Double
    var tax: Double
    var total: Double
    var createdAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, status, subtotal, tax, total
        case organizationId = "organization_id"
        case poNumber = "po_number"
        case supplierName = "supplier_name"
        case createdAt = "created_at"
    }
}

struct ERPAttendance: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    let employeeId: UUID
    var workDate: String
    var checkIn: Date?
    var checkOut: Date?
    var status: String
    enum CodingKeys: String, CodingKey {
        case id, status
        case organizationId = "organization_id"
        case employeeId = "employee_id"
        case workDate = "work_date"
        case checkIn = "check_in"
        case checkOut = "check_out"
    }
}

struct ERPPayroll: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    let employeeId: UUID
    var period: String
    var baseSalary: Double
    var allowances: Double
    var deductions: Double
    var netSalary: Double
    var status: String
    enum CodingKeys: String, CodingKey {
        case id, period, allowances, deductions, status
        case organizationId = "organization_id"
        case employeeId = "employee_id"
        case baseSalary = "base_salary"
        case netSalary = "net_salary"
    }
}

struct ERPAuditLog: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var actorId: UUID?
    var action: String
    var entity: String
    var entityId: UUID?
    var payload: [String: String]?
    var createdAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, action, entity, payload
        case organizationId = "organization_id"
        case actorId = "actor_id"
        case entityId = "entity_id"
        case createdAt = "created_at"
    }
}

struct POSCartItem: Identifiable, Hashable {
    var id: UUID { product.id }
    var product: ERPProduct
    var quantity: Double
    var lineSubtotal: Double { product.salePrice * quantity }
    var tax: Double { lineSubtotal * 0.15 }
    var lineTotal: Double { lineSubtotal + tax }
}
