import SwiftUI
import PhotosUI
import AuthenticationServices

struct ContentView: View {
    @EnvironmentObject private var model: NOWModel
    @State private var showInterests = false
    var body: some View {
        Group {
            if model.isRestoring { ProgressView("Preparando NOW…") }
            else if model.user == nil { WelcomeView() }
            else { MainView() }
        }
        .preferredColorScheme(.light)
        .task { await model.restore(); if model.user?.preferences.interests.isEmpty == true { showInterests = true } }
        .onChange(of: model.user?.preferences.interests.isEmpty) { empty in if empty == true { showInterests = true } }
        .sheet(isPresented: $showInterests) { InterestSetupScreen().interactiveDismissDisabled(model.user?.preferences.interests.isEmpty == true) }
        .overlay(alignment: .top) { if let notice = model.latestInterestAlert { Text(notice + " · Abre NOW cuando te apetezca.").font(.subheadline.weight(.semibold)).padding(14).frame(maxWidth: .infinity).background(NOWTheme.soft).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 18).padding(.top, 8).onTapGesture { model.latestInterestAlert = nil } } }
        .alert("NOW", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Reintentar") { Task { await model.retryConnection() } }
            Button("Cerrar", role: .cancel) {}
        } message: { Text(model.error ?? "") }
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var model: NOWModel
    @State private var showLogin = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            Text("NOW.").font(.system(size: 38, weight: .black, design: .rounded)).foregroundStyle(NOWTheme.ink)
            Spacer(minLength: 18)
            Text("LA VIDA NO NECESITA TANTO PLAN").font(.caption2.bold()).tracking(1.8).foregroundStyle(NOWTheme.moss)
            Text("Estoy libre.\nAbro NOW.").font(.system(size: 58, weight: .semibold, design: .rounded)).tracking(-3).foregroundStyle(NOWTheme.ink)
            Text("Un café. Un paseo. Lo que surja.\nDi qué te apetece y encuentra a quienes también tienen un rato, ahora.").foregroundStyle(NOWTheme.muted).lineSpacing(5)
            if model.isDemo {
                Button("Probar mi primer NOW ↗") { Task { await model.demoLogin() } }.buttonStyle(NOWPrimaryButton()).disabled(model.isBusy)
                Text("Entorno local · personas y lugares ficticios").font(.caption).foregroundStyle(NOWTheme.muted).frame(maxWidth: .infinity)
            }
            if model.isDemo { Button("Crear cuenta o entrar") { showLogin = true }.buttonStyle(NOWSecondaryButton()) }
            else { Button("Encontrar mi NOW ↗") { showLogin = true }.buttonStyle(NOWPrimaryButton()) }
            RadarArtwork().frame(height: 280)
            Text("Grupos de 3–6 · Lugares públicos · Solo +18").font(.caption).foregroundStyle(NOWTheme.muted).frame(maxWidth: .infinity)
        }.padding(24) }.background(NOWTheme.paper.ignoresSafeArea()).sheet(isPresented: $showLogin) { LoginScreen() }
    }
}

private struct LoginScreen: View {
    @EnvironmentObject private var model: NOWModel
    @Environment(\.dismiss) private var dismiss
    @State private var signup = true
    @State private var email = ""
    @State private var name = ""
    @State private var birthDate = ""
    @State private var terms = false
    @State private var code = ""
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Tu próximo NOW empieza aquí.").font(.largeTitle.bold())
            if let challenge = model.challenge {
                Text("Introduce el código de seis cifras enviado a tu email.").foregroundStyle(NOWTheme.muted)
                if model.isDemo, let demoCode = challenge.demoCode { Text("Código local: \(demoCode)").foregroundStyle(NOWTheme.moss) }
                TextField("Código de seis cifras", text: $code).textContentType(.oneTimeCode).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Button("Entrar →") { Task { await model.verifyCode(code); if model.user != nil { dismiss() } } }.buttonStyle(NOWPrimaryButton()).disabled(code.count != 6 || model.isBusy)
            } else {
                if model.appleSignInEnabled {
                    SignInWithAppleButton(signup ? .signUp : .signIn, onRequest: { request in request.nonce = model.appleChallenge?.nonce }, onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential, let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { model.error = "Apple no devolvió un token válido."; return }
                            Task { await model.signInApple(token, name: signup ? name : nil, birthDate: signup ? birthDate : nil, terms: terms); if model.user != nil { dismiss() } }
                        case .failure(let error): if (error as? ASAuthorizationError)?.code != .canceled { model.error = error.localizedDescription }
                        }
                    }).signInWithAppleButtonStyle(.black).frame(height: 48).disabled(model.isBusy || model.appleChallenge == nil || (signup && (name.count < 2 || birthDate.isEmpty || !terms)))
                    Text("O continúa con tu email").font(.caption).foregroundStyle(NOWTheme.muted).frame(maxWidth: .infinity)
                }
                Picker("Acceso", selection: $signup) { Text("Crear cuenta").tag(true); Text("Ya tengo cuenta").tag(false) }.pickerStyle(.segmented)
                TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textContentType(.emailAddress).textFieldStyle(.roundedBorder)
                if signup {
                    TextField("Nombre visible", text: $name).textContentType(.givenName).textFieldStyle(.roundedBorder)
                    TextField("Fecha de nacimiento (AAAA-MM-DD)", text: $birthDate).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder)
                    Toggle("Acepto las normas y he leído la privacidad", isOn: $terms).font(.callout)
                    if let url = URL(string: model.privacyURL) { Link("Leer privacidad", destination: url) }
                }
                Button("Recibir código →") { Task { await model.requestCode(email: email, name: signup ? name : nil, birthDate: signup ? birthDate : nil, terms: terms) } }.buttonStyle(NOWPrimaryButton()).disabled(email.isEmpty || (signup && (name.count < 2 || birthDate.isEmpty || !terms)) || model.isBusy)
            }
        }.padding(24) }.navigationTitle("Entrar").toolbar { Button("Cerrar") { dismiss() } } }.task { await model.prepareAppleSignIn() }
    }
}

private struct MainView: View {
    var body: some View {
        TabView {
            NavigationStack { NOWHome() }.tabItem { Label("NOW", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { CommunitiesScreen() }.tabItem { Label("Comunidad", systemImage: "circle.grid.cross") }
            NavigationStack { ConversationsScreen() }.tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            NavigationStack { ProfileScreen() }.tabItem { Label("Perfil", systemImage: "person.crop.circle") }
            NavigationStack { PrivacyScreen() }.tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
        }.tint(NOWTheme.ink)
    }
}

private struct NOWHome: View {
    @EnvironmentObject private var model: NOWModel
    @State private var step = 0
    @State private var activity = "social"
    @State private var subtype = ""
    @State private var minutes = 120
    @State private var radius = 2_000
    @State private var locationSheet = false

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("TU PRÓXIMO BUEN RATO").eyebrow()
            Text(model.radar?.match?.state == "CONFIRMED" ? "Ya tienes un NOW." : "¿Qué te apetece, \(model.user?.displayName.components(separatedBy: " ").first ?? "hoy")?").font(.largeTitle.bold()).tracking(-1.6)
            Text("No hace falta tener un plan. Solo un poco de tiempo.").foregroundStyle(NOWTheme.muted)
            if let match = model.radar?.match, !model.dismissedMatches.contains(match.id) { MatchCard(match: match) }
            else if let intent = model.radar?.intent { SearchingCard(intent: intent) }
            else { IntentCard(step: $step, activity: $activity, subtype: $subtype, minutes: $minutes, radius: $radius, showLocation: $locationSheet) }
            Text("✳ El mejor tiempo en NOW es el que pasas fuera.").font(.caption).foregroundStyle(NOWTheme.muted).frame(maxWidth: .infinity)
        }.padding(20) }
        .background(NOWTheme.paper).navigationTitle("NOW.").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button { model.showSafety = true } label: { Image(systemName: "shield.lefthalf.filled") }.accessibilityLabel("Centro de seguridad") }
        .sheet(isPresented: $locationSheet) { LocationConsent { step = 1 } }
        .sheet(isPresented: $model.showSafety) { SafetyCenter() }
        .task { await model.refreshRadar() }.refreshable { await model.refreshRadar() }
    }
}

private struct IntentCard: View {
    @EnvironmentObject private var model: NOWModel
    @Binding var step: Int; @Binding var activity: String; @Binding var subtype: String; @Binding var minutes: Int; @Binding var radius: Int; @Binding var showLocation: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("PASO \(step + 1) DE 4").eyebrow(); Spacer(); if step > 0 { Button("← Atrás") { step -= 1 } } }
            Text(step == 0 ? "Todo empieza con un\n«me apetece…»" : step == 1 ? "¿Qué tipo de plan?" : step == 2 ? "¿Cuánto tiempo\ntienes para ti?" : "Buena compañía.\nA tu manera.").font(.title.bold())
            if step == 0 {
                LazyVGrid(columns: [.init(.flexible()),.init(.flexible()),.init(.flexible())], spacing: 10) {
                    ForEach(model.activities) { item in
                        Button { activity = item.id; subtype = ""; model.location.coordinate == nil ? (showLocation = true) : (step = 1) } label: {
                            VStack(alignment: .leading, spacing: 10) { Text(item.emoji).font(.title); Text(item.label).font(.caption.bold()).lineLimit(1) }.frame(maxWidth: .infinity, minHeight: 72, alignment: .leading).padding(11).background(NOWTheme.paper).clipShape(RoundedRectangle(cornerRadius: 14))
                        }.foregroundStyle(NOWTheme.ink).accessibilityLabel(item.label)
                    }
                }
                Picker("Radio", selection: $radius) { Text("1 km").tag(1_000); Text("2 km").tag(2_000); Text("3 km").tag(3_000); Text("5 km").tag(5_000) }.pickerStyle(.segmented)
                Label("Solo tú ves tu intención", systemImage: "lock.fill").font(.caption).foregroundStyle(NOWTheme.muted)
            } else if step == 1 {
                ForEach(model.activities.first(where: { $0.id == activity })?.options ?? []) { option in
                    Button { subtype = option.id; step = 2 } label: { HStack { Text(option.emoji); Text(option.label).font(.headline); Spacer(); Image(systemName: "arrow.up.right") }.padding().background(NOWTheme.paper).clipShape(RoundedRectangle(cornerRadius: 14)) }.foregroundStyle(NOWTheme.ink)
                }
            } else if step == 2 {
                ForEach([(30,"30 min"),(60,"1 hora"),(120,"2 horas"),(240,"Toda la tarde")], id: \.0) { value, label in
                    Button { minutes = value; step = 3 } label: { HStack { Image(systemName: "clock"); Text(label).font(.headline); Spacer(); Image(systemName: "arrow.up.right") }.padding().background(NOWTheme.paper).clipShape(RoundedRectangle(cornerRadius: 14)) }.foregroundStyle(NOWTheme.ink)
                }
            } else {
                ScopeButton(title: "Mis amigos", detail: "La gente con la que ya conectas.", value: "friends", step: $step, activity: activity, subtype: subtype, minutes: minutes, radius: radius)
                ScopeButton(title: "Amigos de amigos", detail: "Tu círculo, un poco más grande.", value: "fof", step: $step, activity: activity, subtype: subtype, minutes: minutes, radius: radius)
                ScopeButton(title: "Mi comunidad", detail: model.user?.communities.first(where: { $0.verified })?.name ?? "Verifica tu comunidad para empezar.", value: "community", step: $step, activity: activity, subtype: subtype, minutes: minutes, radius: radius)
                Text("\(minutes) minutos · \(radius / 1000) km · Tu intención desaparece al terminar.").font(.caption).foregroundStyle(NOWTheme.muted)
            }
        }.nowCard()
    }
}

private struct ScopeButton: View {
    @EnvironmentObject private var model: NOWModel
    let title: String, detail: String, value: String; @Binding var step: Int; let activity: String, subtype: String, minutes: Int, radius: Int
    var body: some View { Button { Task { await model.createIntent(activity: activity, subtype: subtype, minutes: minutes, radius: radius, visibility: value); if model.radar?.intent != nil { step = 0 } } } label: { VStack(alignment: .leading, spacing: 5) { HStack { Text(title).font(.headline); Spacer(); Image(systemName: "arrow.up.right") }; Text(detail).font(.caption).foregroundStyle(NOWTheme.muted) }.padding().background(NOWTheme.paper).clipShape(RoundedRectangle(cornerRadius: 14)) }.foregroundStyle(NOWTheme.ink).disabled(model.isBusy) }
}

private struct SearchingCard: View {
    @EnvironmentObject private var model: NOWModel; let intent: IntentView
    var body: some View { VStack(spacing: 18) { Text("TU INTENCIÓN ESTÁ EN EL AIRE").eyebrow(); RadarArtwork().frame(height: 240); Text("Buscando ese «¿y si…?»").font(.title2.bold()); Text(model.radar?.message ?? "Buscando un grupo compatible.").foregroundStyle(NOWTheme.muted).multilineTextAlignment(.center); Text("Hasta las \(intent.expiresAt.formattedTime) · \(intent.radius / 1000) km").font(.caption); Button("Cambiar actividad") { Task { await model.cancelIntent(intent.id) } }.buttonStyle(NOWSecondaryButton()) }.nowCard() }
}

private struct MatchCard: View {
    @EnvironmentObject private var model: NOWModel; let match: MatchView
    var body: some View { VStack(spacing: 18) {
        Text(match.state == "CONFIRMED" ? "CONFIRMADO. AHORA, A VIVIR." : match.state == "COMPLETED" ? "UN RATO QUE CUENTA" : "HAY UN GRUPO QUE ENCAJA CONTIGO").eyebrow()
        Text(match.state == "COMPLETED" ? "✳" : match.activity.emoji).font(.system(size: 62)); Text(match.state == "CONFIRMED" ? "Nos vemos fuera." : match.state == "COMPLETED" ? "Un buen NOW." : "\(match.activity.label). ¿NOW?").font(.title.bold())
        Text("\(match.size) personas · \(match.scheduledAt.formattedTime) · \(match.distance)").font(.caption).foregroundStyle(NOWTheme.muted)
        if let venue = match.venue { VStack(alignment: .leading, spacing: 5) { Text("PUNTO DE ENCUENTRO PÚBLICO").eyebrow(); Text(venue.name).font(.headline); Text(venue.address).font(.caption).foregroundStyle(NOWTheme.muted); if match.isDemo { Text("Lugar ficticio de demostración").font(.caption2).foregroundStyle(NOWTheme.moss) } }.frame(maxWidth: .infinity, alignment: .leading).padding().background(NOWTheme.soft).clipShape(RoundedRectangle(cornerRadius: 14)) }
        else { Label("El grupo y el lugar exacto aparecen cuando todos aceptan.", systemImage: "lock.shield").font(.caption).foregroundStyle(NOWTheme.muted) }
        if match.state == "PROPOSAL_PENDING" || match.state == "PARTIALLY_ACCEPTED" {
            if match.myResponse == "accepted" { ProgressView("Esperando al resto del grupo…") }
            else { Button("VOY ↗") { Task { await model.respond(match.id, response: "accepted") } }.buttonStyle(NOWPrimaryButton()); Button("Ahora paso") { Task { await model.respond(match.id, response: "passed") } }.buttonStyle(NOWSecondaryButton()) }
        } else if match.state == "CONFIRMED" {
            Button(match.checkedIn ? "✓ Ya estás aquí" : "Estoy aquí") { Task { await model.checkIn(match.id) } }.buttonStyle(NOWPrimaryButton()).disabled(match.checkedIn)
            Button("Compartir encuentro") { model.share(match) }.buttonStyle(NOWSecondaryButton()); Button("Centro de seguridad") { model.showSafety = true }.buttonStyle(NOWSecondaryButton())
            if match.isDemo { Button("Demo: simular el final") { Task { await model.completeDemo(match.id) } }.font(.caption) }
        } else if match.state == "COMPLETED" { Text("La asistencia se ha registrado. Tu fiabilidad se actualiza en privado.").foregroundStyle(NOWTheme.muted).multilineTextAlignment(.center); Button("Volver a Mi NOW →") { model.dismissedMatches.insert(match.id) }.buttonStyle(NOWPrimaryButton()) }
        if match.chatOpen { NavigationLink("Chat de este NOW →", destination: ChatScreen(matchId: match.id, chatOpen: match.chatOpen)).buttonStyle(NOWSecondaryButton()) }
    }.nowCard() }
}

private struct CommunitiesScreen: View {
    @EnvironmentObject private var model: NOWModel
    @State private var code = ""
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("UN PUNTO EN COMÚN").eyebrow(); Text("Tu gente empieza aquí.").font(.largeTitle.bold())
            ForEach(model.communities) { community in
                VStack(alignment: .leading, spacing: 13) {
                    Image(systemName: "circle.grid.cross").font(.system(size: 45)).foregroundStyle(NOWTheme.moss)
                    Text(community.name).font(.title2.bold()); Text(community.description).foregroundStyle(NOWTheme.muted)
                    Text("\(community.memberCount) personas · \(community.eventCount) NOWs").font(.subheadline.bold()).foregroundStyle(NOWTheme.ink)
                    if community.verified {
                        Label("Comunidad verificada", systemImage: "checkmark.shield.fill").font(.caption).foregroundStyle(NOWTheme.moss)
                        Text("\(community.unmetCount) personas por conocer").font(.caption).foregroundStyle(NOWTheme.muted)
                        if !community.metMembers.isEmpty { Text("Ya coincidiste con").font(.headline); ForEach(community.metMembers) { person in HStack { AvatarView(avatar: person.avatar, fallback: person.displayName); Text(person.displayName) } } }
                        NavigationLink("Ver encuentros de la comunidad →", destination: CommunityEventsScreen(community: community)).buttonStyle(NOWSecondaryButton())
                    }
                    else {
                        TextField("Código de comunidad", text: $code).textFieldStyle(.roundedBorder).textInputAutocapitalization(.characters)
                        Button("Unirme →") { Task { await model.join(community.id, code: code) } }.buttonStyle(NOWPrimaryButton())
                    }
                }.nowCard()
            }
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Comunidades").task { await model.loadCommunities() }
    }
}

private struct CommunityEventsScreen: View {
    @EnvironmentObject private var model: NOWModel
    let community: Community
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("\(community.eventCount) NOWs en \(community.name)").font(.title.bold())
            ForEach(model.communityEvents[community.id] ?? []) { event in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(event.activity.emoji) \(event.activity.label)").font(.headline)
                    Text("\(event.scheduledAt.formattedDate) · \(event.attendeeCount) asistencias").foregroundStyle(NOWTheme.muted)
                    if event.attendedByMe, let attendees = event.attendees {
                        Text("Coincidiste con").font(.subheadline.bold())
                        ForEach(attendees) { person in HStack { AvatarView(avatar: person.avatar, fallback: person.displayName); Text(person.displayName) } }
                    } else { Text("Los asistentes se muestran si participaste en este NOW.").font(.caption).foregroundStyle(NOWTheme.muted) }
                }.nowCard()
            }
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Encuentros").task { await model.loadCommunityEvents(community.id) }
    }
}

private struct ProfileScreen: View {
    @EnvironmentObject private var model: NOWModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var name = ""
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("TU HISTORIA FUERA DE LA PANTALLA").eyebrow()
            Text("Tus NOWs.").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) { AvatarView(avatar: model.user?.avatar, fallback: model.user?.displayName ?? "N", size: 70); VStack(alignment: .leading) { Text(model.user?.displayName ?? "").font(.title2.bold()); Text("@" + (model.user?.username ?? "")).foregroundStyle(NOWTheme.muted) } }
                PhotosPicker("Cambiar foto de perfil", selection: $selectedPhoto, matching: .images).buttonStyle(NOWSecondaryButton())
                if model.user?.avatarPending == true { Text("Tu nueva foto está pendiente de revisión.").font(.caption).foregroundStyle(NOWTheme.muted) }
                if model.user?.avatar != nil { Button("Quitar foto") { Task { await model.removeAvatar() } }.font(.caption) }
                TextField("Nombre visible", text: $name).textFieldStyle(.roundedBorder)
                Button("Guardar nombre") { Task { await model.updateName(name) } }.buttonStyle(NOWSecondaryButton()).disabled(name.count < 2)
                NavigationLink("Editar mis intereses y avisos →", destination: InterestSetupScreen()).buttonStyle(NOWSecondaryButton())
            }.nowCard()
            if !model.friendRequests.isEmpty {
                Text("Solicitudes de amistad").font(.title2.bold())
                ForEach(model.friendRequests) { person in HStack(spacing: 12) { AvatarView(avatar: person.avatar, fallback: person.displayName); Text(person.displayName).font(.subheadline.bold()); Spacer(); Button("Aceptar") { Task { await model.acceptFriendRequest(person.id) } }.buttonStyle(NOWSecondaryButton()) }.nowCard() }
            }
            Text("Personas con las que coincidiste").font(.title2.bold())
            if model.people.isEmpty { Text("Aquí verás a las personas con las que asististe a un NOW.").foregroundStyle(NOWTheme.muted) }
            else { VStack(alignment: .leading, spacing: 12) { ForEach(model.people) { person in NavigationLink(destination: PersonProfileScreen(person: person)) { HStack { AvatarView(avatar: person.avatar, fallback: person.displayName); Text(person.displayName); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(NOWTheme.muted) }.contentShape(Rectangle()) }.buttonStyle(.plain) } }.nowCard() }
            Text("Histórico de NOWs").font(.title2.bold())
            ForEach(model.history) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(item.activity.emoji) \(item.activity.label)").font(.headline)
                    Text(item.scheduledAt.formattedDate + (item.community.map { " · " + $0.name } ?? "")).foregroundStyle(NOWTheme.muted)
                    Text(item.participants.map(\.displayName).joined(separator: ", ")).font(.caption)
                    if item.chatOpen { NavigationLink("Abrir chat →", destination: ChatScreen(matchId: item.id, chatOpen: item.chatOpen)).buttonStyle(NOWSecondaryButton()) }
                }.nowCard()
            }
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Mi perfil").task { await model.loadProfile(); name = model.user?.displayName ?? "" }
        .onChange(of: selectedPhoto) { item in Task { if let data = try? await item?.loadTransferable(type: Data.self) { await model.updateAvatar(data) } } }
    }
}


private struct PersonProfileScreen: View {
    @EnvironmentObject private var model: NOWModel
    let person: PersonSummary
    @State private var profile: PublicPersonProfile?
    @State private var draft = ""
    private var key: String { "direct-" + person.id }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) { AvatarView(avatar: profile?.avatar ?? person.avatar, fallback: person.displayName, size: 64); VStack(alignment: .leading) { Text(profile?.displayName ?? person.displayName).font(.title2.bold()); Text("Habéis coincidido en \(profile?.sharedNows ?? 0) \((profile?.sharedNows ?? 0) == 1 ? "NOW" : "NOWs")").foregroundStyle(NOWTheme.muted) } }.nowCard()
            if let profile, profile.friendStatus == "friends" {
                VStack(alignment: .leading, spacing: 10) { Text("Chat privado").font(.headline); ForEach(model.messages[key] ?? []) { message in VStack(alignment: .leading, spacing: 5) { if message.senderId != model.user?.id { Text(message.displayName).font(.caption.bold()).foregroundStyle(NOWTheme.moss) }; Text(message.body); if message.senderId == model.user?.id { Text(message.delivery == "read" ? "Leído" : message.delivery == "received" ? "Recibido" : "Enviado").font(.caption2).foregroundStyle(message.delivery == "read" ? .green : NOWTheme.moss) } }.padding(12).frame(maxWidth: .infinity, alignment: message.senderId == model.user?.id ? .trailing : .leading).background(message.senderId == model.user?.id ? Color.green.opacity(0.13) : NOWTheme.soft).clipShape(RoundedRectangle(cornerRadius: 14)) }; HStack { TextField("Escribe un mensaje", text: $draft).textFieldStyle(.roundedBorder); Button("Enviar") { let text = draft; draft = ""; Task { await model.sendDirectMessage(person.id, body: text) } }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.nowCard()
            } else if profile?.friendStatus == "outgoing" { Text("Solicitud enviada. Podrás escribir cuando la acepte.").foregroundStyle(NOWTheme.muted).nowCard() }
            else if profile?.friendStatus == "incoming" { Button("Aceptar solicitud") { Task { await model.requestFriend(person.id); await load() } }.buttonStyle(NOWPrimaryButton()) }
            else { Button("Enviar solicitud de amistad") { Task { await model.requestFriend(person.id); await load() } }.buttonStyle(NOWPrimaryButton()) }
            Text("Solo mostramos su nombre y foto pública. El chat privado requiere que ambos aceptéis.").font(.caption).foregroundStyle(NOWTheme.muted)
            if let error = model.error { Text(error).foregroundStyle(.red) }
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Perfil público").task { await load() }.task(id: profile?.friendStatus) { while !Task.isCancelled { if profile?.friendStatus == "friends" { await model.loadDirectMessages(person.id) }; try? await Task.sleep(for: .seconds(3)) } }
    }
    private func load() async { await model.loadPublicProfile(person.id); profile = model.publicProfiles[person.id]; if profile?.friendStatus == "friends" { await model.loadDirectMessages(person.id) } }
}

private struct InterestSetupScreen: View {
    @EnvironmentObject private var model: NOWModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<String>()
    @State private var subtypes: [String:[String]] = [:]
    @State private var alerts = false
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("TU PERFIL · TUS PLANES").eyebrow(); Text("¿Qué te apetece hacer?").font(.largeTitle.bold())
            Text("Elige tus intereses y, si quieres, te avisaremos cuando aparezca un NOW cercano que encaje. La zona aproximada caduca a las dos horas.").foregroundStyle(NOWTheme.muted)
            ForEach(model.activities.filter { $0.id != "surprise" }) { activity in
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("\(activity.emoji)  \(activity.label)", isOn: Binding(get: { selected.contains(activity.id) }, set: { on in if on { selected.insert(activity.id) } else { selected.remove(activity.id); subtypes[activity.id] = nil } }))
                    if selected.contains(activity.id) { ForEach(activity.options) { option in Toggle(option.label, isOn: Binding(get: { subtypes[activity.id, default: []].contains(option.id) }, set: { on in var values = subtypes[activity.id, default: []]; if on { values.append(option.id) } else { values.removeAll { $0 == option.id } }; subtypes[activity.id] = values })) }.font(.caption).padding(.leading, 12) }
                }.nowCard()
            }
            Toggle("Avisarme de NOWs cercanos", isOn: $alerts).nowCard()
            if alerts && model.location.coordinate == nil { Button("Activar zona aproximada") { Task { _ = await model.requestLocation() } }.buttonStyle(NOWSecondaryButton()) }
            Text("El aviso no revela quién creó el NOW ni tu ubicación exacta.").font(.caption).foregroundStyle(NOWTheme.muted)
            Button("Guardar intereses →") { Task { await model.saveInterests(Array(selected), subtypes: subtypes, alerts: alerts); if model.error == nil { dismiss() } } }.buttonStyle(NOWPrimaryButton()).disabled(selected.isEmpty || model.isBusy)
            if let error = model.error { Text(error).foregroundStyle(.red) }
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Tus intereses").toolbar { if !((model.user?.preferences.interests.isEmpty) ?? true) { Button("Cerrar") { dismiss() } } } }
        .onAppear { selected = Set(model.user?.preferences.interests ?? []); subtypes = model.user?.preferences.interestSubtypes ?? [:]; alerts = model.user?.preferences.interestAlerts ?? false }
    }
}

private struct ConversationsScreen: View {
    @EnvironmentObject private var model: NOWModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("CONVERSACIONES CON CONTEXTO").eyebrow(); Text("Tus chats.").font(.largeTitle.bold())
            Text("Grupos de NOW y chats privados con amistades.").foregroundStyle(NOWTheme.muted)
            if !model.attendanceReviews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Confirmar asistencia").font(.headline)
                    ForEach(model.attendanceReviews) { review in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(review.activity.emoji) \(review.activity.label)").font(.caption).foregroundStyle(NOWTheme.muted)
                            Text("¿A este Now ha ido \(review.displayName)?").font(.subheadline.weight(.semibold))
                            HStack { Button("No") { Task { await model.answerAttendanceReview(review, attended: false) } }.buttonStyle(NOWSecondaryButton()); Button("Sí") { Task { await model.answerAttendanceReview(review, attended: true) } }.buttonStyle(NOWPrimaryButton()) }
                        }.padding(.vertical, 5)
                    }
                }.nowCard()
            }
            Text("Chats de grupo").font(.title3.bold())
            if model.conversations.isEmpty { Text("Cuando compartas un NOW, aquí podrás retomar la conversación con el grupo.").nowCard() }
            ForEach(model.conversations) { item in
                NavigationLink(destination: ChatScreen(matchId: item.id, chatOpen: item.chatOpen)) {
                    VStack(alignment: .leading, spacing: 8) { Text("\(item.activity.emoji) \(item.activity.label)").font(.headline); Text(item.scheduledAt.formattedDate).font(.caption); Text(item.lastMessage ?? "Abre la conversación").lineLimit(2).foregroundStyle(NOWTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading).nowCard()
                }.foregroundStyle(NOWTheme.ink)
            }
            Text("Chats privados").font(.title3.bold()).padding(.top, 8)
            if model.directConversations.isEmpty { Text("Cuando ambos aceptéis una solicitud y hayáis coincidido, el chat privado aparecerá aquí.").nowCard() }
            ForEach(model.directConversations) { item in
                NavigationLink(destination: PersonProfileScreen(person: PersonSummary(id: item.id, displayName: item.displayName, avatar: item.avatar))) {
                    HStack(spacing: 12) {
                        AvatarView(avatar: item.avatar, fallback: item.displayName, size: 46)
                        VStack(alignment: .leading, spacing: 5) { Text(item.displayName).font(.headline); Text(item.lastMessage).lineLimit(1).font(.subheadline).foregroundStyle(NOWTheme.muted); Text(item.lastMessageAt.formattedDate).font(.caption2).foregroundStyle(NOWTheme.muted) }
                        Spacer(); Text("PRIVADO").font(.system(size: 9, weight: .bold)).padding(.horizontal, 9).padding(.vertical, 6).background(NOWTheme.soft).clipShape(Capsule())
                    }.nowCard()
                }.foregroundStyle(NOWTheme.ink)
            }
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Chats").task { await model.loadConversations() }
    }
}

private struct ChatScreen: View {
    @EnvironmentObject private var model: NOWModel
    let matchId: String
    let chatOpen: Bool
    @State private var draft = ""
    @State private var reportTarget = ""
    @State private var reportDetails = ""
    @State private var showReport = false
    private var messageList: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(model.messages[matchId] ?? []) { message in
                ChatBubble(message: message, isMine: message.senderId == model.user?.id) { reportTarget = message.senderId; showReport = true }
            }
            let people = model.typingPeople[matchId] ?? []
            if !people.isEmpty { TypingIndicator(names: people.map(\.displayName)) }
        }.padding() }
    }
    private var composer: some View {
        HStack {
            TextField("Mensaje al grupo", text: $draft).textFieldStyle(.roundedBorder).onChange(of: draft) { value in
                Task { await model.setChatTyping(matchId, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            Button("Enviar") { let text = draft; draft = ""; Task { await model.sendMessage(matchId, body: text) } }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
        }.padding()
    }
    var body: some View {
        VStack(spacing: 0) {
            messageList
            if chatOpen { composer }
            else { Text("Este chat ya ha terminado.").foregroundStyle(NOWTheme.muted).padding() }
        }.background(NOWTheme.paper).navigationTitle("Chat del NOW").task { if chatOpen { while !Task.isCancelled { await model.loadChatState(matchId); try? await Task.sleep(for: .seconds(2)) } } }
        .sheet(isPresented: $showReport) { NavigationStack { VStack(spacing: 18) { Text("Tu seguridad importa").font(.title.bold()); TextField("¿Qué ha ocurrido?", text: $reportDetails, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder); Button("Enviar reporte") { Task { await model.report(reportTarget, match: matchId, details: reportDetails); if model.error == nil { showReport = false } } }.buttonStyle(NOWSecondaryButton()).disabled(reportDetails.count < 5); Button("Bloquear a esta persona") { Task { await model.block(reportTarget); showReport = false; await model.loadMessages(matchId) } }.buttonStyle(NOWDangerButton()); Spacer() }.padding(24).toolbar { Button("Cerrar") { showReport = false } } } }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let onReport: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !isMine { Text(message.displayName).font(.caption.bold()).foregroundStyle(NOWTheme.moss) }
            Text(message.body)
            if isMine { Text(message.delivery == "read" ? "Leído" : message.delivery == "received" ? "Recibido" : "Enviado").font(.caption2).foregroundStyle(message.delivery == "read" ? .green : NOWTheme.moss) }
            if !isMine { Button("Reportar o bloquear", action: onReport).font(.caption) }
        }.padding(12).frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            .background(isMine ? Color.green.opacity(0.14) : NOWTheme.soft).clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct TypingIndicator: View {
    let names: [String]
    var body: some View { HStack(spacing: 8) { TypingDots(); Text(names.joined(separator: ", ") + (names.count == 1 ? " está escribiendo" : " están escribiendo")).font(.caption).foregroundStyle(NOWTheme.muted) }.padding(10).transition(.opacity.combined(with: .move(edge: .bottom))) }
}

private struct AvatarView: View {
    let avatar: String?
    let fallback: String
    var size: CGFloat = 42
    var body: some View {
        Group { if let avatar, let encoded = avatar.split(separator: ",").last, let data = Data(base64Encoded: String(encoded)), let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Text(String(fallback.prefix(1))).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(NOWTheme.moss).frame(maxWidth: .infinity, maxHeight: .infinity).background(NOWTheme.soft) }
        }.frame(width: size, height: size).clipShape(Circle())
    }
}

private struct TypingDots: View {
    @State private var animate = false
    var body: some View {
        HStack(spacing: 3) { ForEach(0..<3) { index in Circle().fill(NOWTheme.moss).frame(width: 5, height: 5).offset(y: animate ? -3 : 2).animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(index) * 0.12), value: animate) } }
            .padding(.horizontal, 9).padding(.vertical, 8).background(NOWTheme.soft).clipShape(Capsule()).onAppear { animate = true }
    }
}

private struct PrivacyScreen: View {
    @EnvironmentObject private var model: NOWModel
    @State private var deleteText = ""
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("TÚ DECIDES").eyebrow(); Text("Tu espacio. Tus límites.").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 16) {
                Text("Sin ruido.").font(.title2.bold())
                Toggle("Notificaciones", isOn: Binding(get: { model.user?.preferences.notifications ?? false }, set: { value in Task { await model.setNotifications(value) } }))
                if let url = URL(string: model.privacyURL) { Link("Política de privacidad ↗", destination: url) }
                if let email = model.supportEmail, let url = URL(string: "mailto:" + email) { Link("Contactar con soporte ↗", destination: url) }
                Text("Sin GPS de fondo. Sin historial de movimientos. La celda de matching se elimina al terminar.").foregroundStyle(NOWTheme.muted)
                Button("Retirar ubicación y detener radar") { Task { await model.withdrawLocation() } }.buttonStyle(NOWSecondaryButton())
            }.nowCard()
            VStack(alignment: .leading, spacing: 14) {
                Text("Tu fiabilidad").font(.headline); Text("\(model.user?.reliability.score ?? 0)%").font(.system(size: 42, weight: .semibold)).foregroundStyle(NOWTheme.moss)
                Text("Señal privada de asistencia. No es una puntuación social pública.").font(.caption).foregroundStyle(NOWTheme.muted)
            }.nowCard()
            VStack(alignment: .leading, spacing: 14) {
                Text("Tu cuenta").font(.title2.bold()); Button("Cerrar sesión") { Task { await model.logout() } }.buttonStyle(NOWSecondaryButton())
                SecureField("Escribe ELIMINAR para borrar", text: $deleteText).textFieldStyle(.roundedBorder)
                Button("Eliminar mi cuenta") { Task { await model.deleteAccount() } }.buttonStyle(NOWDangerButton()).disabled(deleteText != "ELIMINAR")
            }.nowCard()
        }.padding(20) }.background(NOWTheme.paper).navigationTitle("Privacidad")
    }
}

private struct LocationConsent: View {
    @EnvironmentObject private var model: NOWModel; @Environment(\.dismiss) private var dismiss; let ready: () -> Void
    var body: some View { VStack(spacing: 22) {
        Image(systemName: "location.circle.fill").font(.system(size: 62)).foregroundStyle(NOWTheme.moss); Text("Cerca, sin localizarte.").font(.title.bold())
        Text("Usamos tu ubicación solo al activar el radar. Se redondea y se elimina al terminar. Nadie verá dónde estás.").foregroundStyle(NOWTheme.muted).multilineTextAlignment(.center)
        Button("Usar mi ubicación →") { Task { if await model.requestLocation() { ready(); dismiss() } } }.buttonStyle(NOWPrimaryButton())
        if model.isDemo { Button("Usar campus de demostración") { model.location.useDemoCampus(); ready(); dismiss() }.buttonStyle(NOWSecondaryButton()) }
        Text("Sin ubicación en segundo plano. Sin historial.").font(.caption).foregroundStyle(NOWTheme.muted)
    }.padding(28).presentationDetents([.medium]) }
}

private struct SafetyCenter: View {
    @EnvironmentObject private var model: NOWModel; @Environment(\.dismiss) private var dismiss
    @State private var target = ""
    @State private var details = ""
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 18) {
        Image(systemName: "shield.lefthalf.filled").font(.system(size: 45)).foregroundStyle(NOWTheme.moss); Text("Tu tranquilidad, primero.").font(.largeTitle.bold())
        Text("Puedes abandonar sin explicar el motivo. Una salida de seguridad no reduce tu fiabilidad.").foregroundStyle(NOWTheme.muted)
        Link("Emergencia real · Llamar al 112", destination: URL(string: "tel:112")!).buttonStyle(NOWDangerButton()); Text("NOW no es un servicio de emergencias.").font(.caption).foregroundStyle(NOWTheme.muted)
        if let match = model.radar?.match {
            Button("No me siento a gusto. Salir.") { Task { await model.safeExit(match.id); dismiss() } }.buttonStyle(NOWSecondaryButton())
            if match.venue != nil { Button("Compartir con alguien de confianza") { model.share(match) }.buttonStyle(NOWSecondaryButton()) }
            if match.participants.count > 1 {
                Text("Reportar o bloquear").font(.headline)
                Picker("Persona", selection: $target) { Text("Selecciona una persona").tag(""); ForEach(match.participants.filter { $0.id != model.user?.id }) { person in Text(person.displayName).tag(person.id) } }.pickerStyle(.menu)
                TextField("¿Qué ha ocurrido?", text: $details, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
                Button("Enviar reporte") { Task { await model.report(target, match: match.id, details: details); if model.error == nil { dismiss() } } }.buttonStyle(NOWSecondaryButton()).disabled(target.isEmpty || details.count < 5)
                Button("Bloquear y salir") { Task { await model.block(target); dismiss() } }.buttonStyle(NOWDangerButton()).disabled(target.isEmpty)
            }
        }
        Text("Queda en un lugar público. No envíes dinero ni datos privados.").font(.callout).foregroundStyle(NOWTheme.muted)
    }.padding(24) } .toolbar { Button("Cerrar") { dismiss() } } } }
}

private struct RadarArtwork: View {
    var body: some View { ZStack {
        Circle().stroke(NOWTheme.moss.opacity(0.25)); Circle().stroke(NOWTheme.moss.opacity(0.25)).scaleEffect(0.68); Circle().stroke(NOWTheme.moss.opacity(0.25)).scaleEffect(0.36)
        Circle().fill(NOWTheme.ink).frame(width: 66, height: 66).overlay(Text("n.").font(.system(size: 38, weight: .black, design: .rounded)).italic().foregroundStyle(NOWTheme.lime))
        Text("☕").radarOrb().offset(x: -90, y: -65); Text("🍺").radarOrb().offset(x: 100, y: 18); Text("⚽").radarOrb().offset(x: -50, y: 100)
    }.padding(18).accessibilityElement(children: .ignore).accessibilityLabel("Radar abstracto. Muestra posibilidades, no posiciones.") }
}

private extension View {
    func nowCard() -> some View { padding(22).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(NOWTheme.line)) }
    func radarOrb() -> some View { frame(width: 42, height: 42).background(Color.white).clipShape(Circle()).overlay(Circle().stroke(NOWTheme.line)) }
    func eyebrow() -> some View { font(.caption2.bold()).tracking(1.5).foregroundStyle(NOWTheme.moss) }
}

private enum NOWTheme {
    static let paper = Color(red: 0.97, green: 0.975, blue: 0.95), soft = Color(red: 0.93, green: 0.95, blue: 0.90)
    static let ink = Color(red: 0.09, green: 0.23, blue: 0.17), muted = Color(red: 0.38, green: 0.46, blue: 0.39)
    static let moss = Color(red: 0.37, green: 0.52, blue: 0.24), lime = Color(red: 0.85, green: 0.98, blue: 0.38), line = Color(red: 0.86, green: 0.89, blue: 0.83)
}
private struct NOWPrimaryButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.headline).foregroundStyle(NOWTheme.ink).padding().frame(maxWidth: .infinity, minHeight: 50).background(NOWTheme.lime.opacity(configuration.isPressed ? 0.7 : 1)).clipShape(RoundedRectangle(cornerRadius: 13)) } }
private struct NOWSecondaryButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.subheadline.bold()).foregroundStyle(NOWTheme.ink).padding().frame(maxWidth: .infinity, minHeight: 50).background(NOWTheme.soft.opacity(configuration.isPressed ? 0.65 : 1)).clipShape(RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(NOWTheme.line)) } }
private struct NOWDangerButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.subheadline.bold()).foregroundStyle(Color(red: 0.62, green: 0.20, blue: 0.16)).padding().frame(maxWidth: .infinity, minHeight: 50).background(Color(red: 1, green: 0.93, blue: 0.91)).clipShape(RoundedRectangle(cornerRadius: 13)) } }

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView().environmentObject(NOWModel.preview) }
}
