import SwiftUI
import CoreLocation

@MainActor final class NOWModel: ObservableObject {
    @Published var user: UserView?
    @Published var radar: RadarViewModel?
    @Published var latestInterestAlert: String?
    private var knownNotificationIds = Set<String>()
    private var didLoadNotifications = false
    @Published var activities: [ActivityType] = []
    @Published var communities: [Community] = []
    @Published var communityEvents: [String:[CommunityEvent]] = [:]
    @Published var history: [HistoryItem] = []
    @Published var conversations: [HistoryItem] = []
    @Published var directConversations: [DirectConversation] = []
    @Published var attendanceReviews: [AttendanceReview] = []
    @Published var people: [PersonSummary] = []
    @Published var friendRequests: [PersonSummary] = []
    @Published var typingPeople: [String:[PersonSummary]] = [:]
    @Published var publicProfiles: [String:PublicPersonProfile] = [:]
    @Published var messages: [String:[ChatMessage]] = [:]
    @Published var challenge: AuthChallenge?
    @Published var appleSignInEnabled = false
    @Published var appleChallenge: OIDCChallenge?
    @Published var isDemo = false
    @Published var privacyURL = ""
    @Published var supportEmail: String?
    @Published var isBusy = false
    @Published var isRestoring = true
    @Published var error: String?
    @Published var showSafety = false
    @Published var dismissedMatches = Set<String>()
    let location = NOWLocation()
    private let client = NOWClient()
    private var refreshTask: Task<Void,Never>?
    private var typingTasks: [String:Task<Void,Never>] = [:]
    private var activeTypingChats = Set<String>()

    static let preview: NOWModel = { let value = NOWModel(); value.isRestoring = false; return value }()

    func restore() async {
        guard isRestoring else { return }
        do {
            let config = try await client.config(); activities = config.activities; isDemo = config.demo; appleSignInEnabled = config.providers?.apple ?? false; privacyURL = config.privacyUrl; supportEmail = config.supportEmail
            if await client.hasSession() { user = try await client.me(); await refreshRadar(); startPolling() }
        } catch { self.error = error.localizedDescription }
        isRestoring = false
    }

    func retryConnection() async { isRestoring = true; error = nil; await restore() }

    func demoLogin() async { await run { user = try await client.demoLogin(); await refreshRadar(); startPolling() } }
    func requestCode(email: String, name: String?, birthDate: String?, terms: Bool) async { await run { challenge = try await client.requestCode(email: email, displayName: name, birthDate: birthDate, terms: terms) } }
    func prepareAppleSignIn() async { guard appleSignInEnabled else { return }; await run { appleChallenge = try await client.oidcNonce("apple") } }
    func signInApple(_ token: String, name: String?, birthDate: String?, terms: Bool) async { guard let appleChallenge else { error = "Prepara de nuevo el acceso con Apple."; return }; await run { user = try await client.oidcLogin("apple", token: token, nonce: appleChallenge, displayName: name, birthDate: birthDate, terms: terms); self.appleChallenge = nil; challenge = nil; await refreshRadar(); startPolling() } }
    func verifyCode(_ code: String) async { guard let challenge else { return }; await run { user = try await client.verifyCode(challenge, code: code); self.challenge = nil; await refreshRadar(); startPolling() } }
    func refreshRadar() async { guard user != nil else { return }; do { radar = try await client.radar(); let notes = try await client.notifications(); if !didLoadNotifications { knownNotificationIds = Set(notes.map(\.id)); didLoadNotifications = true } else { if let fresh = notes.first(where: { $0.kind == "interest" && !knownNotificationIds.contains($0.id) }) { latestInterestAlert = fresh.title }; knownNotificationIds.formUnion(notes.map(\.id)) } } catch { self.error = error.localizedDescription } }
    func loadCommunities() async { await run { communities = try await client.communities() } }
    func loadCommunityEvents(_ id: String) async { await run { communityEvents[id] = try await client.communityEvents(id) } }
    func loadProfile() async { await run { history = try await client.history(); people = try await client.people(); friendRequests = try await client.friendRequests(); user = try await client.me() } }
    func loadConversations() async { await run { async let groups = client.conversations(); async let direct = client.directConversations(); async let reviews = client.attendanceReviews(); conversations = try await groups; directConversations = try await direct; attendanceReviews = try await reviews } }
    func answerAttendanceReview(_ review: AttendanceReview, attended: Bool) async { await run { try await client.answerAttendanceReview(review, attended: attended); attendanceReviews.removeAll { $0.id == review.id } } }
    func loadMessages(_ id: String) async { await run { messages[id] = try await client.messages(id) } }
    func loadChatState(_ id: String) async { await run { messages[id] = try await client.messages(id); try await client.readMessages(id); typingPeople[id] = try await client.typing(id) } }
    func setChatTyping(_ id: String, _ value: Bool) async {
        if value {
            guard activeTypingChats.insert(id).inserted else { return }
            typingTasks[id] = Task { try? await Task.sleep(for: .milliseconds(350)); if !Task.isCancelled { try? await client.setTyping(id, true) } }
        } else {
            activeTypingChats.remove(id); typingTasks[id]?.cancel(); typingTasks[id] = nil
            do { try await client.setTyping(id, false) } catch { }
        }
    }
    func sendMessage(_ id: String, body: String) async { await run { try await client.setTyping(id, false); try await client.sendMessage(id, body: body); messages[id] = try await client.messages(id); conversations = try await client.conversations() } }
    func loadDirectMessages(_ id: String) async { await run { messages["direct-"+id] = try await client.directMessages(id); try await client.readDirectMessages(id) } }
    func sendDirectMessage(_ id: String, body: String) async { await run { try await client.sendDirectMessage(id, body: body); messages["direct-"+id] = try await client.directMessages(id) } }
    func requestFriend(_ id: String) async { await run { _ = try await client.requestFriend(id); friendRequests = try await client.friendRequests() } }
    func acceptFriendRequest(_ id: String) async { await run { try await client.acceptFriendRequest(id); friendRequests = try await client.friendRequests() } }
    func declineFriendRequest(_ id: String) async { await run { try await client.declineFriendRequest(id); friendRequests = try await client.friendRequests() } }
    func loadPublicProfile(_ id: String) async { await run { publicProfiles[id] = try await client.publicPerson(id) } }
    func report(_ person: String, match: String, details: String) async { await run { try await client.report(person, match: match, details: details) } }
    func block(_ person: String) async { await run { try await client.block(person); await refreshRadar() } }
    func updateName(_ name: String) async { await run { user = try await client.updateName(name) } }
    func updateAvatar(_ data: Data) async {
        await run {
            guard let image = UIImage(data: data) else { throw NOWClientError.message("No pudimos abrir esa foto.") }
            let size = CGSize(width: 256, height: 256)
            let result = UIGraphicsImageRenderer(size: size).image { _ in
                let side = min(image.size.width, image.size.height)
                let origin = CGPoint(x: (image.size.width-side)/2, y: (image.size.height-side)/2)
                image.draw(in: CGRect(x: -origin.x*size.width/side, y: -origin.y*size.height/side, width: image.size.width*size.width/side, height: image.size.height*size.height/side))
            }
            guard let jpeg = result.jpegData(compressionQuality: 0.78) else { throw NOWClientError.message("No pudimos preparar esa foto.") }
            user = try await client.avatar("data:image/jpeg;base64," + jpeg.base64EncodedString())
        }
    }
    func removeAvatar() async { await run { user = try await client.avatar(nil) } }
    func join(_ id: String, code: String) async { await run { try await client.join(id, code: code); communities = try await client.communities(); user = try await client.me() } }
    func requestLocation() async -> Bool { do { let granted = try await location.request(); if granted { try await client.consentLocation(true) }; return granted } catch { self.error = error.localizedDescription; return false } }

    func createIntent(activity: String, subtype: String, minutes: Int, radius: Int, visibility: String) async {
        guard let coordinate = location.coordinate else { error = "Activa la ubicación para entrar en el radar."; return }
        let community = user?.communities.first(where: { $0.verified })?.id
        if visibility == "community", community == nil { error = "Verifica una comunidad antes de usarla."; return }
        await run {
            try await client.createIntent(activity: activity, subtype: subtype, minutes: minutes, radius: radius, visibility: visibility, communityId: visibility == "community" ? community : nil, latitude: coordinate.latitude, longitude: coordinate.longitude)
            await refreshRadar()
        }
    }

    func cancelIntent(_ id: String) async { await run { try await client.cancelIntent(id); await refreshRadar() } }
    func respond(_ id: String, response: String) async { await run { _ = try await client.respond(id, response: response); await refreshRadar() } }
    func checkIn(_ id: String) async { await run { _ = try await client.checkIn(id); await refreshRadar() } }
    func safeExit(_ id: String) async { await run { try await client.safeExit(id); await refreshRadar() } }
    func completeDemo(_ id: String) async { await run { _ = try await client.completeDemo(id); user = try await client.me(); await refreshRadar() } }
    func withdrawLocation() async { await run { try await client.withdrawLocation(); location.clear(); await refreshRadar() } }
    func setNotifications(_ enabled: Bool) async { await run { user = try await client.preferences(notifications: enabled) } }
    func saveInterests(_ interests: [String], subtypes: [String:[String]], alerts: Bool) async { if alerts && location.coordinate == nil { error = "Para avisarte de NOWs cercanos, activa tu ubicación aproximada primero."; return }; await run { user = try await client.saveInterests(interests, subtypes: subtypes, alerts: alerts, location: location.coordinate) } }
    func logout() async { await client.logoutRemote(); reset() }
    func deleteAccount() async { await run { try await client.deleteAccount(); reset() } }

    func share(_ match: MatchView) {
        guard let venue = match.venue else { return }
        let text = "Mi NOW: \(match.activity.label), \(match.scheduledAt.formattedTime), \(venue.name), \(venue.address). \(match.size) personas."
        guard let controller = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        controller.present(UIActivityViewController(activityItems: [text], applicationActivities: nil), animated: true)
    }

    private func reset() { knownNotificationIds.removeAll(); didLoadNotifications = false; latestInterestAlert = nil; refreshTask?.cancel(); refreshTask = nil; user = nil; radar = nil; challenge = nil; history = []; conversations = []; directConversations = []; attendanceReviews = []; people = []; messages = [:]; location.clear() }
    private func startPolling() { refreshTask?.cancel(); refreshTask = Task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(5)); await refreshRadar() } } }
    private func run(_ operation: () async throws -> Void) async { isBusy = true; defer { isBusy = false }; do { try await operation() } catch { self.error = error.localizedDescription } }
}

@MainActor final class NOWLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool,Error>?

    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func request() async throws -> Bool {
        if let coordinate = manager.location?.coordinate { self.coordinate = coordinate; return true }
        manager.requestWhenInUseAuthorization(); manager.requestLocation()
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func useDemoCampus() { coordinate = .init(latitude: 37.36, longitude: -5.985) }
    func clear() { coordinate = nil; manager.stopUpdatingLocation() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { coordinate = locations.last?.coordinate; continuation?.resume(returning: coordinate != nil); continuation = nil }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { continuation?.resume(throwing: error); continuation = nil }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { continuation?.resume(throwing: NOWClientError.message("Puedes habilitar la ubicación en Ajustes.")); continuation = nil }
    }
}
