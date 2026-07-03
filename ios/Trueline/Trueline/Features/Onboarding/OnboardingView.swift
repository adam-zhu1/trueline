import SwiftUI

/// First-run intro: where the phone goes, how a session works, what you get.
/// All setup guidance lives here (and in Settings → How TrueLine works) — the
/// record screen stays clean, and precision lives in calibration.
struct OnboardingView: View {
    var onDone: () -> Void

    @State private var page = 0

    private struct Page {
        let icon: String
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(
            icon: "iphone",
            title: "Set up behind the approach",
            text: "Prop your phone on the ball return or a table behind the approach, looking straight down your lane. Get the whole lane in frame — foul line to pins — and don't move the phone between throws."
        ),
        Page(
            icon: "viewfinder",
            title: "Your first throw calibrates",
            text: "Record a throw, then drag the four corners onto the lane — TrueLine finds them for you, you just fine-tune. Every following throw reuses that calibration: just bowl."
        ),
        Page(
            icon: "chart.line.uptrend.xyaxis",
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
                        .opacity(page == pages.count - 1 ? 0 : 1)
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 24) {
                            Image(systemName: pages[i].icon)
                                .font(.system(size: 72))
                                .foregroundStyle(.tint)
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
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page == pages.count - 1 {
                        onDone()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Start Bowling" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingView {}
}
