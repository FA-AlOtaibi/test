import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://hgwjverwrpzwyixkprqo.supabase.co")!
    static let publishableKey = "sb_publishable_uHay3RzUOZ1J59IqCxO_HA_WLokij3y"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: publishableKey
    )
}
