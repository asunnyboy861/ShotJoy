import SwiftUI

struct ContactSupportView: View {
    @State private var subject = "General"
    @State private var customSubject = ""
    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var feedbackBanner: String?
    @State private var isSuccess = false

    private let backendURL = "https://msg.calcs.top"
    private let maxMessageLength = 1000

    private struct SubjectOption {
        let title: String
        let icon: String
    }

    private let subjects: [SubjectOption] = [
        SubjectOption(title: "General", icon: "bubble.left.fill"),
        SubjectOption(title: "Feature Suggestion", icon: "lightbulb.fill"),
        SubjectOption(title: "Bug Report", icon: "ant.fill"),
        SubjectOption(title: "Usage Question", icon: "questionmark.circle.fill"),
        SubjectOption(title: "Performance Issue", icon: "gauge.with.dots.needle.67percent"),
        SubjectOption(title: "UI Improvement", icon: "paintpalette.fill"),
        SubjectOption(title: "Other", icon: "ellipsis.circle.fill")
    ]

    private var emailValid: Bool {
        email.contains("@") && email.contains(".") && email.count > 4
    }

    private var canSubmit: Bool {
        !name.isEmpty && emailValid && !message.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                subjectGrid
                if subject == "Other" {
                    TextField("Tell us the topic…", text: $customSubject)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline.weight(.medium))
                    TextField("Your name", text: $name)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.subheadline.weight(.medium))
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    if !email.isEmpty && !emailValid {
                        Text("That email doesn't look right yet.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message")
                        .font(.subheadline.weight(.medium))
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: message) { _, value in
                                if value.count > maxMessageLength {
                                    message = String(value.prefix(maxMessageLength))
                                }
                            }
                        if message.isEmpty {
                            Text("Tell us what's on your mind…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 14)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    Text("\(message.count) / \(maxMessageLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Submit")
                            .font(.headline)
                    }
                }
                .buttonStyle(BigActionButtonStyle())
                .disabled(!canSubmit || isSubmitting)
                .opacity(canSubmit ? 1 : 0.5)

                if let banner = feedbackBanner {
                    Label(banner, systemImage: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundStyle(isSuccess ? AppTheme.mint : .red)
                        .transition(.opacity)
                }

                Text("We only use your email to respond to this feedback.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Contact Support")
        .background(Color(.systemBackground))
    }

    private var subjectGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(subjects, id: \.title) { option in
                let selected = subject == option.title
                Button {
                    subject = option.title
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: option.icon)
                            .font(.title3)
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selected ? AppTheme.coral : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(selected ? .white : .primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(selected ? AppTheme.coral : Color(.separator), lineWidth: selected ? 2 : 0.5)
                    )
                    .scaleEffect(selected ? 1.02 : 1)
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.title) topic")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        withAnimation { feedbackBanner = nil }
        defer { isSubmitting = false }
        let finalSubject = subject == "Other" ? (customSubject.isEmpty ? "Other" : customSubject) : subject
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "subject": finalSubject,
            "message": message,
            "app_name": "ShotJoy"
        ]
        guard let url = URL(string: backendURL + "/api/feedback"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            withAnimation { feedbackBanner = "Something went wrong. Please try again."; isSuccess = false }
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = payload
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], obj["success"] as? Bool == true {
                withAnimation {
                    feedbackBanner = "Thank you! Your feedback has been sent."
                    isSuccess = true
                }
                name = ""
                email = ""
                message = ""
                customSubject = ""
                subject = "General"
            } else {
                let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                withAnimation {
                    feedbackBanner = serverMessage ?? "Something went wrong. Please try again."
                    isSuccess = false
                }
            }
        } catch {
            withAnimation {
                feedbackBanner = "Couldn't reach the server. Please try again."
                isSuccess = false
            }
        }
    }
}
