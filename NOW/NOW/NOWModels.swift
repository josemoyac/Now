import Foundation

struct UserView: Codable {
    let id: String
    let displayName: String
    let username: String
    let avatar: String?
    let avatarPending: Bool
    let isDemo: Bool
    let reliability: Reliability
    var preferences: Preferences
    var communities: [CommunitySummary]
}

struct Reliability: Codable { let score: Int; let attended: Int; let accepted: Int }
struct Preferences: Codable { var notifications: Bool; let liquidity: Bool; let quietStart: Int; let quietEnd: Int; let timezone: String; let radius: Int; let analytics: Bool; var interests: [String]; var interestSubtypes: [String:[String]]; var interestAlerts: Bool }
struct CommunitySummary: Codable, Identifiable { let id: String; let name: String; let verified: Bool }
struct PersonSummary: Codable, Identifiable { let id: String; let displayName: String; let avatar: String? }
struct PublicPersonProfile: Codable { let id: String; let displayName: String; let avatar: String?; let sharedNows: Int; var friendStatus: String }
struct Community: Codable, Identifiable { let id: String; let name: String; let kind: String; let city: String; let description: String; let method: String; let joined: Bool; let verified: Bool; let memberCount: Int; let eventCount: Int; let metMembers: [PersonSummary]; let unmetCount: Int }
struct ActivityOption: Codable, Identifiable { let id: String; let label: String; let emoji: String }
struct ActivityType: Codable, Identifiable { let id: String; let label: String; let emoji: String; let family: String; let compatible: [String]; let options: [ActivityOption]; let enabled: Bool; let minMinutes: Int }
struct CommunityEvent: Codable, Identifiable { let id: String; let activity: ActivityType; let subtype: String?; let scheduledAt: String; let venue: String?; let attendeeCount: Int; let attendees: [PersonSummary]?; let attendedByMe: Bool }
struct HistoryCommunity: Codable { let id: String; let name: String }
struct HistoryItem: Codable, Identifiable { let id: String; let activity: ActivityType; let subtype: String?; let scheduledAt: String; let state: String; let community: HistoryCommunity?; let participants: [PersonSummary]; let chatOpen: Bool; let lastMessage: String? }
struct DirectConversation: Codable, Identifiable { let id: String; let displayName: String; let avatar: String?; let lastMessage: String; let lastMessageAt: String }
struct AttendanceReview: Codable, Identifiable { let id: String; let matchId: String; let subjectId: String; let displayName: String; let activity: ReviewActivity; let scheduledAt: String; let otherReviewersNeeded: Int }
struct ReviewActivity: Codable { let id: String; let label: String; let emoji: String }
struct ChatMessage: Codable, Identifiable { let id: String; let senderId: String; let displayName: String; let body: String; let createdAt: String; let delivery: String? }
struct ProviderAvailability: Codable { let google: Bool; let apple: Bool }
struct PublicConfig: Codable { let demo: Bool; let activities: [ActivityType]; let privacyUrl: String; let supportEmail: String?; let providers: ProviderAvailability? }
struct OIDCChallenge: Codable { let challenge: String; let nonce: String; let binding: String }
struct IntentView: Codable { let id: String; let activity: String; let subtype: String?; let status: String; let expiresAt: String; let radius: Int; let visibility: String }
struct RadarViewModel: Codable { let intent: IntentView?; let signal: String; let countBand: String; let message: String; let match: MatchView? }
struct MatchView: Codable {
    let id: String; let state: String; let activity: ActivityType; let subtype: String?; let communityId: String?
    let scheduledAt: String; let endsAt: String; let expiresAt: String
    let size: Int; let accepted: Int; let myResponse: String; let distance: String
    let venue: Venue?; let participants: [Participant]; let checkedIn: Bool; let chatOpen: Bool; let chatExpiresAt: String?; let isDemo: Bool
}
struct Venue: Codable { let id: String; let name: String; let address: String; let category: String; let accessible: Bool; let isDemo: Bool }
struct Participant: Codable, Identifiable { let id: String; let displayName: String; let avatar: String?; let checkedIn: Bool }
struct AuthChallenge: Codable { let challenge: String; let binding: String; let demoCode: String? }
struct AuthResponse: Codable { let accessToken: String; let refreshToken: String; let sessionId: String; let user: UserView }
struct APIErrorBody: Codable { let code: String; let message: String }
struct APIEmpty: Codable { let ok: Bool? }

extension String {
    var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: self) else { return self }
        return date.formatted(date: .omitted, time: .shortened)
    }
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: self) else { return self }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct NOWNotification: Codable, Identifiable { let id: String; let kind: String; let title: String; let body: String; let read: Bool; let createdAt: String }
