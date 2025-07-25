import SwiftUI

struct CoFlyerDetailView: View {
    // MARK: - Properties
    let contractor: ContractorProfile
    
    @EnvironmentObject var authController: AuthController
    @EnvironmentObject var chatController: ChatController
    @EnvironmentObject var flyerController: FlyerController
    
    @State private var isFullScreen: Bool = false
    @State private var isLoading: Bool = false
    @State private var conversationId: String? = nil
    @State private var showMessageView: Bool = false
    @State private var navigateToChatView: Bool = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        if let imageURL = contractor.imageURL, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: 300)
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        isFullScreen = true
                                    }
                            } placeholder: {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            }
                        }
                        
                        Text(contractor.contractorName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.leading)
                        
                        Text("Service Area: \(contractor.city)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.leading)
                        
                        Text("Contact: \(contractor.email)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.leading)
                        
                        Text(contractor.bio)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.leading)
                    }
                    .padding(.bottom, 20)
                }
                
                Spacer()
                    .sheet(isPresented: $showMessageView) {
                        if let conversationId = conversationId {
                            HoChatDetailView(conversationId: conversationId, receiverId: contractor.contractorId)
                                .environmentObject(chatController)
                                .environmentObject(authController)
                                .presentationDetents([.fraction(0.9), .large])
                                .presentationDragIndicator(.visible)
                        } else {
                            Text("Unable to load conversation.")
                        }
                    }
                    .fullScreenCover(isPresented: $isFullScreen) {
                        FullScreenImageView(imageUrl: contractor.imageURL, isFullScreen: $isFullScreen)
                    }
            }
        }
    }
}

// MARK: - Preview
struct CoFlyerDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleContractor = ContractorProfile(
            id: UUID(),
            contractorId: "sample-contractor-id",
            contractorName: "John Doe",
            bio: "Experienced contractor specializing in home renovations.",
            skills: ["Renovation", "Painting"],
            rating: 4.5,
            jobsCompleted: 10,
            city: "Camarillo",
            email: "johndoe@example.com",
            imageURL: "https://via.placeholder.com/300"
        )

        FlyerDetailView(contractor: sampleContractor)
            .environmentObject(HomeownerJobController())
            .environmentObject(AuthController())
            .environmentObject(JobController())
            .environmentObject(FlyerController())
            .environmentObject(BidController())
            .environmentObject(ContractorController())
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.black)
    }
}
