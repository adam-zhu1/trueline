import SwiftUI

/// First-run intro: where the phone goes, how a session works, what you get.
/// All setup guidance lives here (and in Settings → How TrueLine works) — the
/// record screen stays clean, and precision lives in calibration.
struct OnboardingView: View {
    var onDone: () -> Void

    @AppStorage("bowlingHand") private var bowlingHand = "right"
    // Debug hook: `-onboardingPage <n>` opens on that page (screenshots — the
    // simulator can't swipe from the CLI). Key absent in production: starts at 0.
    @State private var page: Int = {
        #if DEBUG
        UserDefaults.standard.integer(forKey: "onboardingPage")
        #else
        0
        #endif
    }()

    private struct Page {
        let art: OnboardingArtView.Art
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(
            art: .setup,
            title: "Set up behind the approach",
            text: "Prop your phone on the ball return or a table behind the approach, looking straight down your lane. Get the whole lane in frame — foul line to pins — and don't move the phone between throws."
        ),
        Page(
            art: .calibrate,
            title: "Your first throw calibrates",
            text: "Record a throw, then drag the four corners onto the lane — TrueLine finds them for you, you just fine-tune. Every following throw reuses that calibration: just bowl."
        ),
        Page(
            art: .metrics,
            title: "Every throw, measured",
            text: "Speed, board at the arrows, breakpoint, and where the ball enters the pocket — plus how consistent they are across the session. The numbers a coach would give you."
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { onDone() }
                        .foregroundStyle(.secondary)
                        .padding()
                        .opacity(page == pages.count ? 0 : 1)
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 24) {
                            OnboardingArtView(art: pages[i].art)
                            Text(pages[i].title)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            Text(pages[i].text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                        .tag(i)
                    }
                    handPage
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page == pages.count {
                        onDone()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(page == pages.count ? "Start Bowling" : "Continue")
                }
                .buttonStyle(.primaryAction)
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Final page: bowling hand. Boards are numbered from the bowler's side,
    /// so a wrong hand silently mirrors every board number — worth one tap up
    /// front instead of a setting nobody finds.
    private var handPage: some View {
        VStack(spacing: 24) {
            OnboardingArtView(art: .pocket, mirrored: bowlingHand == "left")
                .animation(.easeInOut(duration: 0.4), value: bowlingHand)
            Text("Which hand do you bowl with?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Board numbers count from your side of the lane, so this keeps every number true. You can change it later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            HStack(spacing: 12) {
                handCard("Left", tag: "left")
                handCard("Right", tag: "right")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private func handCard(_ label: String, tag: String) -> some View {
        Button {
            bowlingHand = tag
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .scaleEffect(x: tag == "left" ? -1 : 1)
                Text(label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .foregroundStyle(bowlingHand == tag ? Color.brandMint : .secondary)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(bowlingHand == tag ? Color.brandMint : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView {}
}
