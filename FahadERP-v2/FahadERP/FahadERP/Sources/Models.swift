import Foundation

struct Organization: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var currency: String
    var ownerId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, currency
        case ownerId = "owner_id"
        case createdAt = "created_at"
    }
}

struct ERPProduct: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var sku: String
    var name: String
    var category: String?
    var salePrice: Double
    var costPrice: Double
    var stock: Double
    var reorderLevel: Double
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, sku, name, category, stock
        case organizationId = "organization_id"
        case salePrice = "sale_price"
        case costPrice = "cost_price"
        case reorderLevel = "reorder_level"
        case isActive = "is_active"
    }
}

struct ERPEmployee: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var fullName: String
    var jobTitle: String?
    var department: String?
    var email: String?
    var phone: String?
    var salary: Double
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, email, phone, salary, status, department
        case organizationId = "organization_id"
        case fullName = "full_name"
        case jobTitle = "job_title"
    }
}

struct ERPInvoice: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var invoiceNo: String
    var kind: String
    var partyName: String
    var subtotal: Double
    var tax: Double
    var total: Double
    var status: String
    var issuedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, subtotal, tax, total, status
        case organizationId = "organization_id"
        case invoiceNo = "invoice_no"
        case partyName = "party_name"
        case issuedAt = "issued_at"
    }
}

struct ERPExpense: Codable, Identifiable, Hashable {
    let id: UUID
    let organizationId: UUID
    var title: String
    var category: String?
    var amount: Double
    var occurredAt: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, title, category, amount, notes
        case organizationId = "organization_id"
        case occurredAt = "occurred_at"
    }
}

struct DashboardMetrics {
    var revenue: Double = 0
    var expenses: Double = 0
    var stockValue: Double = 0
    var employees: Int = 0
    var lowStock: Int = 0
}
