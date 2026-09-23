import Foundation
import Security
import CoreLocation

enum NOWClientError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return "No se pudo completar la operación." }
}

actor NOWClient {
    struct Tokens: Codable { let access: String; let refresh: String }
    private let session = URLSession(configuration: .ephemeral)
    private let decoder = JSONDecoder()
    private let baseURL: URL
    private var tokens: Tokens?

    init(baseURL: URL = URL(string: ProcessInfo.processInfo.environment["NOW_API_URL"] ?? (Bundle.main.object(forInfoDictionaryKey: "NOW_API_URL") as? String ?? "http://127.0.0.1:4000"))!) {
        self.baseURL = baseURL
        if ProcessInfo.processInfo.environment["NOW_UI_TEST_RESET"] == "1" { KeychainStore.delete() }
        tokens = KeychainStore.load()
    }

    func hasSession() -> Bool { tokens != nil }
    func config() async throws -> PublicConfig { try await request("/v1/config", authenticated: false) }
    func me() async throws -> UserView { try await request("/v1/me") }
    func radar() async throws -> RadarViewModel { try await request("/v1/radar") }
    func notifications() async throws -> [NOWNotification] { try await request("/v1/notifications") }
    func communities() async throws -> [Community] { try await request("/v1/communities") }
    func communityEvents(_ id: String) async throws -> [CommunityEvent] { try await request("/v1/communities/\(id)/events") }
    func history() async throws -> [HistoryItem] { try await request("/v1/me/history") }
    func conversations() async throws -> [HistoryItem] { try await request("/v1/me/conversations") }
    func directConversations() async throws -> [DirectConversation] { try await request("/v1/me/direct-conversations") }
    func attendanceReviews() async throws -> [AttendanceReview] { try await request("/v1/me/attendance-reviews") }
    func answerAttendanceReview(_ review: AttendanceReview, attended: Bool) async throws { let _: APIEmpty = try await request("/v1/matches/\(review.matchId)/attendance-reviews/\(review.subjectId)", method: "POST", body: ["attended":attended]) }
    func people() async throws -> [PersonSummary] { try await request("/v1/me/people") }
    func friendRequests() async throws -> [PersonSummary] { try await request("/v1/friend-requests") }
    func acceptFriendRequest(_ id: String) async throws { let _: [String:String] = try await request("/v1/friends/\(id)/accept", method: "POST", body: [String:String]()) }
    func declineFriendRequest(_ id: String) async throws { let _: APIEmpty = try await request("/v1/friends/\(id)/request", method: "DELETE") }
    func publicPerson(_ id: String) async throws -> PublicPersonProfile { try await request("/v1/people/\(id)") }
    func requestFriend(_ id: String) async throws -> [String:String] { try await request("/v1/people/\(id)/friend-request", method: "POST", body: [String:String]()) }
    func directMessages(_ id: String) async throws -> [ChatMessage] { try await request("/v1/people/\(id)/messages") }
    func sendDirectMessage(_ id: String, body: String) async throws { let _: [String:String] = try await request("/v1/people/\(id)/messages", method: "POST", body: ["body":body]) }
    func readDirectMessages(_ id: String) async throws { let _: APIEmpty = try await request("/v1/people/\(id)/messages/read", method: "POST", body: [String:String]()) }
    func messages(_ id: String) async throws -> [ChatMessage] { try await request("/v1/matches/\(id)/messages") }
    func typing(_ id: String) async throws -> [PersonSummary] { try await request("/v1/matches/\(id)/typing") }
    func setTyping(_ id: String, _ typing: Bool) async throws { let _: APIEmpty = try await request("/v1/matches/\(id)/typing", method: "POST", body: ["typing":typing]) }
    func readMessages(_ id: String) async throws { let _: APIEmpty = try await request("/v1/matches/\(id)/messages/read", method: "POST", body: [String:String]()) }
    func sendMessage(_ id: String, body: String) async throws { let _: [String:String] = try await request("/v1/matches/\(id)/messages", method: "POST", body: ["body":body]) }
    func report(_ person: String, match: String, details: String) async throws { let _: [String:String] = try await request("/v1/reports", method: "POST", body: ["subjectId":person,"matchId":match,"category":"safety","details":details], idempotency: true) }
    func block(_ person: String) async throws { let _: APIEmpty = try await request("/v1/users/\(person)/block", method: "POST", body: [String:String]()) }
    func avatar(_ image: String?) async throws -> UserView { try await request("/v1/me/avatar", method: "PUT", body: ["image":image as Any? ?? NSNull()]) }
    func updateName(_ name: String) async throws -> UserView { try await request("/v1/me", method: "PATCH", body: ["displayName":name]) }

    func oidcNonce(_ provider: String) async throws -> OIDCChallenge { try await request("/v1/auth/oidc/nonce", method: "POST", body: ["provider":provider], authenticated: false) }
    func oidcLogin(_ provider: String, token: String, nonce: OIDCChallenge, displayName: String?, birthDate: String?, terms: Bool) async throws -> UserView {
        var body: [String:Any] = ["provider":provider,"idToken":token,"nonce":nonce.nonce,"challenge":nonce.challenge,"binding":nonce.binding]
        if let displayName, let birthDate { body["displayName"] = displayName; body["birthDate"] = birthDate; body["terms"] = terms }
        let result: AuthResponse = try await request("/v1/auth/oidc", method: "POST", body: body, authenticated: false)
        tokens = Tokens(access: result.accessToken, refresh: result.refreshToken); KeychainStore.save(tokens!); return result.user
    }

    func requestCode(email: String, displayName: String?, birthDate: String?, terms: Bool) async throws -> AuthChallenge {
        var body: [String:Any] = ["email":email]
        if let displayName, let birthDate { body["displayName"] = displayName; body["birthDate"] = birthDate; body["terms"] = terms }
        return try await request("/v1/auth/request", method: "POST", body: body, authenticated: false)
    }

    func verifyCode(_ challenge: AuthChallenge, code: String) async throws -> UserView {
        let result: AuthResponse = try await request("/v1/auth/verify", method: "POST", body: ["challenge":challenge.challenge,"binding":challenge.binding,"code":code,"device":"iPhone"], authenticated: false)
        tokens = Tokens(access: result.accessToken, refresh: result.refreshToken)
        KeychainStore.save(tokens!)
        return result.user
    }

    func demoLogin() async throws -> UserView {
        let result: AuthResponse = try await request("/v1/auth/demo", method: "POST", body: ["email":"jose@now.demo"], authenticated: false)
        tokens = Tokens(access: result.accessToken, refresh: result.refreshToken)
        KeychainStore.save(tokens!)
        return result.user
    }

    func join(_ community: String, code: String) async throws {
        let _: APIEmpty = try await request("/v1/communities/\(community)/join", method: "POST", body: ["code":code])
    }

    func createIntent(activity: String, subtype: String, minutes: Int, radius: Int, visibility: String, communityId: String?, latitude: Double, longitude: Double) async throws {
        var body: [String:Any] = ["activity":activity,"subtype":subtype,"minutes":minutes,"startsIn":0,"radius":radius,"visibility":visibility,"location":["lat":latitude,"lon":longitude],"budget":1,"accessible":false]
        if let communityId { body["communityId"] = communityId }
        let _: [String:String] = try await request("/v1/intents", method: "POST", body: body, idempotency: true)
    }

    func cancelIntent(_ id: String) async throws { let _: APIEmpty = try await request("/v1/intents/\(id)", method: "DELETE") }
    func respond(_ id: String, response: String) async throws -> MatchView { try await request("/v1/matches/\(id)/respond", method: "POST", body: ["response":response], idempotency: true) }
    func checkIn(_ id: String) async throws -> MatchView { try await request("/v1/matches/\(id)/check-in", method: "POST", body: [String:String](), idempotency: true) }
    func safeExit(_ id: String) async throws { let _: APIEmpty = try await request("/v1/matches/\(id)/leave", method: "POST", body: [String:String]()) }
    func completeDemo(_ id: String) async throws -> MatchView { try await request("/v1/demo/matches/\(id)/complete", method: "POST", body: [String:String]()) }
    func consentLocation(_ granted: Bool) async throws { let _: APIEmpty = try await request("/v1/consents", method: "POST", body: ["purpose":"location","granted":granted]) }
    func withdrawLocation() async throws { try await consentLocation(false) }
    func preferences(notifications: Bool) async throws -> UserView { try await request("/v1/preferences", method: "PATCH", body: ["notifications":notifications]) }
    func saveInterests(_ interests: [String], subtypes: [String:[String]], alerts: Bool, location: CLLocationCoordinate2D?) async throws -> UserView { let user: UserView = try await request("/v1/preferences", method: "PATCH", body: ["interests":interests,"interestSubtypes":subtypes,"interestAlerts":alerts]); if alerts, let location { let _: APIEmpty = try await request("/v1/me/interest-location", method: "POST", body: ["location":["lat":location.latitude,"lon":location.longitude]]) }; return user }
    func deleteAccount() async throws { let _: APIEmpty = try await request("/v1/account", method: "DELETE"); logout() }
    func logoutRemote() async { let _: APIEmpty? = try? await request("/v1/auth/logout", method: "POST", body: [String:String]()); logout() }
    func logout() { tokens = nil; KeychainStore.delete() }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Any? = nil, authenticated: Bool = true, idempotency: Bool = false, retry: Bool = true) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.httpMethod = method; request.timeoutInterval = 15
        request.setValue("mobile", forHTTPHeaderField: "X-Now-Client")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated, let access = tokens?.access { request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization") }
        if idempotency { request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .networkConnectionLost {
            throw NOWClientError.message("No puedo conectar con la API de NOW. En Xcode, selecciona el esquema compartido NOW y vuelve a ejecutar; la API demo arrancará automáticamente.")
        } catch {
            throw NOWClientError.message("No hay conexión con NOW. Comprueba la red y vuelve a intentarlo.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        if status == 401, retry, authenticated, await refresh() { return try await self.request(path, method: method, body: body, authenticated: authenticated, idempotency: idempotency, retry: false) }
        guard (200..<300).contains(status) else {
            let error = try? decoder.decode(APIErrorBody.self, from: data)
            throw NOWClientError.message(error?.message ?? "No se pudo completar la operación.")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func refresh() async -> Bool {
        guard let refresh = tokens?.refresh else { return false }
        do {
            let result: AuthResponse = try await request("/v1/auth/refresh", method: "POST", body: ["refreshToken":refresh], authenticated: false, retry: false)
            tokens = Tokens(access: result.accessToken, refresh: result.refreshToken); KeychainStore.save(tokens!); return true
        } catch { logout(); return false }
    }
}

private enum KeychainStore {
    static let service = "app.now.social.session", account = "primary"
    static func save(_ tokens: NOWClient.Tokens) {
        delete(); guard let data = try? JSONEncoder().encode(tokens) else { return }
        SecItemAdd([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:account,kSecValueData:data,kSecAttrAccessible:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary, nil)
    }
    static func load() -> NOWClient.Tokens? {
        var out: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:account,kSecReturnData:true,kSecMatchLimit:kSecMatchLimitOne] as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(NOWClient.Tokens.self, from: data)
    }
    static func delete() { SecItemDelete([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:account] as CFDictionary) }
}
