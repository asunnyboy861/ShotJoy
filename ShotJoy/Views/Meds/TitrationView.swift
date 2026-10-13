import SwiftUI
import SwiftData

struct TitrationView: View {
    @Query private var doseLogs: [DoseLog]
    @Query private var goalsList: [GoalSettings]

    @State private var stepUpDays: [Int] = [1]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Up-titration calendar", systemImage: "calendar.badge.plus")
                        .font(.headline)
                    Text("Mark the days you increase your prescribed dose. ShotJoy shows what's common to feel — it never suggests when or how much to increase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        ForEach(1...8, id: \.self) { week in
                            VStack(spacing: 4) {
                                Text("W\(week)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Circle()
                                    .fill(stepUpDays.contains(week) ? AppTheme.coral : AppTheme.cardBackground)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(AppTheme.coral.opacity(0.4)))
                                    .onTapGesture {
                                        if week > 1 {
                                            if stepUpDays.contains(week) { stepUpDays.removeAll { $0 == week } } else { stepUpDays.append(week) }
                                        }
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))

                educationCards

                AppTheme.disclaimerFooter
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Titration mode")
        .background(Color(.systemBackground))
    }

    private var educationCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What's common when doses change", systemImage: "book.fill")
                .font(.headline)
            EducationRow(day: "Day 1–2", text: "Appetite drop and mild nausea are the most commonly reported effects in the first days after a dose increase in community reports.")
            EducationRow(day: "Day 2–3", text: "Nausea often peaks around day 2 after a step-up, then eases for many people.")
            EducationRow(day: "Day 4–7", text: "Digestive effects usually settle within the first week. Protein intake and hydration are what community members most often mention as helpful.")
            Text("If symptoms feel severe or persist, contact your prescriber. ShotJoy is a tracker, not a treatment guide.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct EducationRow: View {
    let day: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(day)
                .font(.caption.bold())
                .padding(6)
                .background(AppTheme.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 64, alignment: .center)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
