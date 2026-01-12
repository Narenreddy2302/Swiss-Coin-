import SwiftUI

struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    // Namespace for MatchedGeometryEffect
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = index
                    }
                }) {
                    ZStack {
                        if selection == index {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                // Light gray/elevated background for selection
                                .matchedGeometryEffect(id: "selection", in: namespace)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }

                        Text(options[index])
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selection == index ? .primary : .secondary)
                            .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemFill))  // Darker background track
        .cornerRadius(10)
    }
}

struct CustomSegmentedControl_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CustomSegmentedControl(selection: .constant(0), options: ["People", "Groups"])
            CustomSegmentedControl(selection: .constant(1), options: ["Personal", "Shared"])
        }
        .padding()
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
