import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - IdentifiableError
struct IdentifiableErrorCO: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - ContractorProfileView
struct ContractorProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    // MARK: - Environment Objects
    @EnvironmentObject var authController: AuthController
    @EnvironmentObject var homeownerJobController: HomeownerJobController
    @EnvironmentObject var jobController: JobController
    @EnvironmentObject var flyerController: FlyerController
    @EnvironmentObject var bidController: BidController
    @EnvironmentObject var contractorController: ContractorController
    @EnvironmentObject var chatController: ChatController
    
    @State private var profileImage: Image? = Image("profilePlaceholder")
    @State private var name: String = ""
    @State private var location: String = ""
    @State private var bio: String = ""
    @State private var flyers: [ContractorProfile] = []
    @State private var navigateToCoChat: Bool = false
    @State private var navigateToBiography: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: IdentifiableErrorCO?
    @State private var profilePictureURL: String? = nil
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @State private var reviews: [Review] = []
    @State private var rating: Double = 0.0
    @State private var selectedTab: ProfileTab = .flyers
    enum ProfileTab: String, CaseIterable {
        case flyers = "My Flyers"
        case reviews = "My Reviews"
    }
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.2, blue: 0.5).opacity(1.0),
                        Color.black.opacity(0.99)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .blur(radius: 4)
                
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            profileHeader
                            buttonSection
                            tabPicker
                            if selectedTab == .flyers {                                flyerSection
                            } else {
                                reviewSection
                            }
                            Spacer()
                        }
                        .padding(.top, 50)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Back")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        signOut()
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                }
            }
            .alert(item: $errorMessage) { error in
                Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
            .navigationDestination(isPresented: $navigateToCoChat) {
                CoMyJobsView()
            }
            .navigationDestination(isPresented: $navigateToBiography) {
                BiographyViewCO(bio: bio)
            }
            .onAppear(perform: loadUserData)
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    uploadProfileImage(image)
                }
            }
        }
    }
    
    // MARK: - Load User Data for Contractor
    private func loadUserData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                self.errorMessage = IdentifiableErrorCO(message: "Failed to fetch user data: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            if let document = document, document.exists {
                let data = document.data() ?? [:]
                self.name = data["name"] as? String ?? "Unknown"
                self.location = data["city"] as? String ?? "Unknown"
                let role = (data["role"] as? String ?? "Contractor").capitalized
                self.location = "\(role) | \(self.location)"
                self.bio = data["bio"] as? String ?? "No bio available."
                self.profilePictureURL = data["profilePictureURL"] as? String
                loadProfileImage()
                self.rating = data["rating"] as? Double ?? 0.0
                loadProfileImage()
                loadReviews(for: userId)
                
                
                contractorController.fetchFlyersForContractor(contractorId: userId)
                self.isLoading = false
            } else {
                self.errorMessage = IdentifiableErrorCO(message: "User data not found.")
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Load Profile Image
    private func loadProfileImage() {
        guard let profilePictureURL = profilePictureURL else {
            self.isLoading = false
            return
        }
        let storageRef = storage.reference(forURL: profilePictureURL)
        storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
            if let error = error {
                self.errorMessage = IdentifiableErrorCO(message: "Failed to load profile image: \(error.localizedDescription)")
            } else if let imageData = data, let uiImage = UIImage(data: imageData) {
                self.profileImage = Image(uiImage: uiImage)
            }
            self.isLoading = false
        }
    }
    
    // MARK: - Upload Profile Image
    private func uploadProfileImage(_ image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let imageRef = storage.reference().child("profilePictures/\(userId).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        imageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                self.errorMessage = IdentifiableErrorCO(message: "Failed to upload image: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { url, error in
                if let error = error {
                    self.errorMessage = IdentifiableErrorCO(message: "Failed to get download URL: \(error.localizedDescription)")
                    return
                }
                if let url = url {
                    self.profilePictureURL = url.absoluteString
                    db.collection("users").document(userId).updateData(["profilePictureURL": url.absoluteString]) { error in
                        if let error = error {
                            self.errorMessage = IdentifiableErrorCO(message: "Failed to update profile URL: \(error.localizedDescription)")
                        } else {
                            self.loadProfileImage()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Button(action: {
                isImagePickerPresented = true
            }) {
                if let image = profileImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 10)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 10)
                }
            }
            Text(name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(location)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            RatingView(label: "Rating", Rating: rating)
            
        }
    }
    
    // MARK: - Button Section
    private var buttonSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                navigateToCoChat = true
            }) {
                Text("Jobs")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#1E3A8A"), Color(hex: "#2563EB")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
            }
            Button(action: {
                navigateToBiography = true
            }) {
                Text("Bio")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#708090"), Color(hex: "#2F4F4F")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Flyer Section
    private var flyerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(contractorController.contractorFlyers, id: \.id) { flyer in
                NavigationLink(destination: CoFlyerDetailView(contractor: flyer)) {
                    HStack {
                        if let imageURL = flyer.imageURL, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 125, height: 125)
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                    .shadow(radius: 3)
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 125, height: 125)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                            }
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 125, height: 125)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(flyer.contractorName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Text("City: \(flyer.city)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                            Text("Email: \(flyer.email)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                            Text("Skills: \(flyer.skills.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.leading, 10)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.1))
                    )
                    .shadow(radius: 5)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }


    // MARK: - Sign Out
    private func signOut() {
        do {
            try authController.signOut()
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(
                    rootView: SignInView()
                        .environmentObject(HomeownerJobController())
                        .environmentObject(AuthController())
                        .environmentObject(JobController())
                        .environmentObject(FlyerController())
                        .environmentObject(BidController())
                        .environmentObject(ContractorController())
                        .environmentObject(ChatController())
                )
                window.makeKeyAndVisible()
            }
        } catch {
            print("Failed to sign out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack {
            Spacer()
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12))
                        .fontWeight(.semibold)
                        .foregroundColor(selectedTab == tab ? .black : .white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Review Section
    @State private var selectedReview: Review?
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reviews.isEmpty {
                Text("No reviews yet.")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
            } else {
                ForEach(reviews, id: \.id) { review in
                    Button(action: {
                        selectedReview = review
                    }) {
                        HStack(alignment: .top, spacing: 10) {
                            if let imageURL = review.homeownerProfileImageURL, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(review.reviewerName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                                            .foregroundColor(index < Int(review.rating) ? .yellow : .gray)
                                    }
                                }
                                Text(review.text)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(1)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.1))
                        )
                        .shadow(radius: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .sheet(item: $selectedReview) { review in
            ReviewDetailView(review: review)
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Review Detail View Card
    struct ReviewDetailView: View {
        let review: Review

        var body: some View {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.black.opacity(0.9)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Review:")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(review.text.isEmpty ? "No review text provided" : review.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Load Reviews
    func loadReviews(for contractorId: String) {
        db.collection("bids")
            .whereField("contractorId", isEqualTo: contractorId)
            .whereField("status", isEqualTo: Bid.bidStatus.completed.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Failed to fetch reviews: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }

                var reviewsWithImages: [Review] = []
                let group = DispatchGroup()

                for document in documents {
                    let data = document.data()
                    let homeownerId = data["homeownerId"] as? String ?? "Unknown"
                    let reviewText = data["review"] as? String ?? ""
                    let jobRating = data["jobRating"] as? Double ?? 0.0

                    // Skip reviews without text
                    guard !reviewText.isEmpty else { continue }

                    group.enter()
                    bidController.getHomeownerProfile(homeownerId: homeownerId) { profile in
                        let homeownerName = profile?.homeownerName ?? "Anonymous"
                        let homeownerImageURL = profile?.imageURL

                        let review = Review(
                            id: document.documentID,
                            contractorId: contractorId,
                            reviewerName: homeownerName,
                            rating: jobRating,
                            text: reviewText,
                            homeownerProfileImageURL: homeownerImageURL
                        )
                        reviewsWithImages.append(review)
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.reviews = reviewsWithImages
                }
            }
    }
}


// MARK: - Review Model
struct Review: Identifiable {
    let id: String
    let contractorId: String
    let reviewerName: String
    let rating: Double
    let text: String
    var homeownerProfileImageURL: String?
}

// MARK: - Biography View
struct BiographyViewCO: View {
    let bio: String

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Text("Biography")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)

                ScrollView {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview
struct ContractorProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ContractorProfileView()
            .environmentObject(HomeownerJobController())
            .environmentObject(AuthController())
            .environmentObject(JobController())
            .environmentObject(FlyerController())
            .environmentObject(BidController())
            .environmentObject(ContractorController())
            .environmentObject(ChatController())
    }
}
