//
//  ContactDetailsInterface.swift
//  Monal
//
//  Created by Jan on 22.10.21.
//  Copyright © 2021 Monal.im. All rights reserved.
//

//see https://davedelong.com/blog/2018/01/19/simplifying-swift-framework-development/ for explanation of @_exported
@_exported import Foundation
@_exported import CocoaLumberjack
//@_exported import CocoaLumberjackSwift
@_exported import Logging
@_exported import SwiftUI
@_exported import monalxmpp
@_exported import Combine
import PhotosUI
import FLAnimatedImage
import OrderedCollections
import CropViewController

//see https://stackoverflow.com/a/62207329/3528174
//and https://www.hackingwithswift.com/forums/100-days-of-swiftui/extending-shapestyle-for-adding-colors-instead-of-extending-color/12324
public extension ShapeStyle where Self == Color {
    static var interpolatedWindowBackground: Color { Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground }) }
    static var background: Color { Color(UIColor.systemBackground) }
    static var secondaryBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var tertiaryBackground: Color { Color(UIColor.tertiarySystemBackground) }
}

extension Binding {
    func optionalMappedToBool<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { newValue in
                MLAssert(!newValue, "New value should never be true when writing to a binding created by optionalMappedToBool()")
                self.wrappedValue = nil
            }
        )
    }
}
extension Binding {
    func bytecount(mappedTo: Double) -> Binding<Double> where Value == UInt {
        Binding<Double>(
            get: { Double(self.wrappedValue) / mappedTo },
            set: { newValue in self.wrappedValue = UInt(newValue * mappedTo) }
        )
    }
}

class SheetDismisserProtocol: ObservableObject {
    weak var host: UIHostingController<AnyView>? = nil
    func dismiss() {
        host?.dismiss(animated: true)
    }
    func dismissWithoutAnimation() {
        host?.dismiss(animated: false)
    }
    func replace<V>(with view: V) where V: View {
        host?.rootView = AnyView(view)
    }
}

func getContactList(viewContact: (ObservableKVOWrapper<MLContact>?)) -> OrderedSet<ObservableKVOWrapper<MLContact>> {
    if let contact = viewContact {
        if(contact.isMuc) {
            //this uses the account the muc belongs to and treats every other account to be remote,
            //even when multiple accounts of the same monal instance are in the same group
            var contactList : OrderedSet<ObservableKVOWrapper<MLContact>> = OrderedSet()
            for memberInfo in Array(DataLayer.sharedInstance().getMembersAndParticipants(ofMuc: contact.contactJid, forAccountID: contact.accountID)) {
                //jid can be participant_jid (if currently joined to muc) or member_jid (if not joined but member of muc)
                guard let jid = memberInfo["participant_jid"] as? String ?? memberInfo["member_jid"] as? String else {
                    continue
                }
                contactList.append(ObservableKVOWrapper<MLContact>(MLContact.createContact(fromJid: jid, andAccountID: contact.accountID)))
            }
            return contactList
        } else {
            return [contact]
        }
    } else {
        return []
    }
}

func promisifyMucAction(account: xmpp, mucJid: String, action: @escaping () throws -> Void) -> Promise<monal_void_block_t?> {
    return Promise<monal_void_block_t?> { seal in
        DispatchQueue.global(qos: .background).async {
            account.mucProcessor.addUIHandler({_data in let data = _data as! NSDictionary
                let success : Bool = data["success"] as! Bool;
                if !success {
                    seal.reject(data["errorMessage"] as? String ?? "Unknown error!")
                } else {
                    if let callback = data["callback"] {
                        seal.fulfill(objcCast(callback) as monal_void_block_t)
                    } else {
                        seal.fulfill(nil)
                    }
                }
            }, forMuc:mucJid)
            do {
                try action()
            } catch {
                seal.reject(error)
            }
            
        }
    }
}

func mucAffiliationToString(_ affiliation: String?) -> String {
    if let affiliation = affiliation {
        if affiliation == kMucAffiliationOwner {
            return NSLocalizedString("Owner", comment:"muc affiliation")
        } else if affiliation == kMucAffiliationAdmin {
            return NSLocalizedString("Admin", comment:"muc affiliation")
        } else if affiliation == kMucAffiliationMember {
            return NSLocalizedString("Member", comment:"muc affiliation")
        } else if affiliation == kMucAffiliationNone {
            return NSLocalizedString("Participant", comment:"muc affiliation")
        } else if affiliation == kMucAffiliationOutcast {
            return NSLocalizedString("Blocked", comment:"muc affiliation")
        } else if affiliation == kMucActionShowProfile {
            return NSLocalizedString("Open contact details", comment:"muc members list")
        } else if affiliation == kMucActionReinvite {
            return NSLocalizedString("Invite again", comment:"muc invite")
        }
    }
    return NSLocalizedString("<unknown>", comment:"muc affiliation")
}

func mucAffiliationToInt(_ affiliation: String?) -> Int {
    if let affiliation = affiliation {
        if affiliation == kMucAffiliationOwner {
            return 1
        } else if affiliation == kMucAffiliationAdmin {
            return 2
        } else if affiliation == kMucAffiliationMember {
            return 3
        } else if affiliation == kMucAffiliationNone {
            return 4
        } else if affiliation == kMucAffiliationOutcast {
            return 5
        } else if affiliation == kMucActionShowProfile {
            return 1000
        } else if affiliation == kMucActionReinvite {
            return 100
        }
    }
    return 0
}

struct CollapsedPickerStyle: ViewModifier {
    let accessibilityLabel: Text
    func body(content: Content) -> some View {
        Menu {
            content
        } label: {
            Button(action: { }) {
                HStack {
                    Spacer().frame(width:8)
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .foregroundColor(.primary)
                    Spacer().frame(width:8)
                }
                .contentShape(Rectangle())
            }
            .frame(width: 24, height: 20)
            .accessibilityLabel(accessibilityLabel)
        }
    }
    
}
extension View {
    func collapsedPickerStyle(accessibilityLabel label: Text) -> some View {
        self.modifier(CollapsedPickerStyle(accessibilityLabel:label))
    }
}

struct TopRight<T: View>: ViewModifier {
    let overlay: T
    public func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            content
            VStack {
                HStack {
                    Spacer()
                    overlay
                }
                Spacer()
            }
        }
    }
}
extension View {
    func addTopRight<T: View>(view overlayClosure: @autoclosure @escaping () -> T) -> some View {
        modifier(TopRight(overlay:overlayClosure()))
    }
    func addTopRight(@ViewBuilder _ overlayClosure: @escaping () -> some View) -> some View {
        modifier(TopRight(overlay:overlayClosure()))
    }
}

struct MonalProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(Color.accentColor)
            .foregroundColor(Color(UIColor.systemBackground))
            .fontWeight(isEnabled ? .bold : .regular)
            .cornerRadius(10)
    }
}

@ViewBuilder
func buildNotificationStateLabel(_ description: Text, isWorking: Bool) -> some View {
    if(isWorking == true) {
        Label(title: {
            description
        }, icon: {
            Image(systemName: "checkmark.seal")
                .foregroundColor(.green)
        })
    } else {
        Label(title: {
            description
        }, icon: {
            Image(systemName: "xmark.seal")
                .foregroundColor(.red)
        })
    }
}

//see https://github.com/CH3COOH/TOCropViewController/blob/issue/421/Swift/CropViewControllerSwiftUIExample/ImageCropView.swift
public struct ImageCropView: UIViewControllerRepresentable {
    private let configureBlock: (CropViewController) -> Void
    private let originalImage: UIImage
    private let onCanceled: () -> Void
    private let onImageCropped: (UIImage,CGRect,Int) -> Void
    
    @Environment(\.presentationMode) private var presentationMode

    public init(originalImage: UIImage, configureBlock: @escaping (CropViewController) -> Void, onCanceled: @escaping () -> Void, success onImageCropped: @escaping (UIImage,CGRect,Int) -> Void) {
        self.originalImage = originalImage
        self.configureBlock = configureBlock
        self.onCanceled = onCanceled
        self.onImageCropped = onImageCropped
    }

    public func makeUIViewController(context: Context) -> CropViewController {
        let cropController = CropViewController(image: originalImage)
        cropController.delegate = context.coordinator
        configureBlock(cropController)
        return cropController
    }

    public func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            onDismiss: { self.presentationMode.wrappedValue.dismiss() },
            onCanceled: self.onCanceled,
            onImageCropped: self.onImageCropped
        )
    }

    final public class Coordinator: NSObject, CropViewControllerDelegate {
        private let onDismiss: () -> Void
        private let onImageCropped: (UIImage,CGRect,Int) -> Void
        private let onCanceled: () -> Void

        init(onDismiss: @escaping () -> Void, onCanceled: @escaping () -> Void, onImageCropped: @escaping (UIImage,CGRect,Int) -> Void) {
            self.onDismiss = onDismiss
            self.onImageCropped = onImageCropped
            self.onCanceled = onCanceled
        }

        public func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
            self.onImageCropped(image, cropRect, angle)
            self.onDismiss()
        }
        
        public func cropViewController(_ cropViewController: CropViewController, didCropToCircularImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
            self.onImageCropped(image, cropRect, angle)
            self.onDismiss()
        }
        
        public func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
            self.onCanceled()
            self.onDismiss()
        }
    }
}

//see here for some ideas used herein: https://blog.logrocket.com/adding-gifs-ios-app-flanimatedimage-swiftui/#using-flanimatedimage-with-swift
struct GIFViewer: UIViewRepresentable {
    typealias UIViewType = FLAnimatedImageView
    @Binding var data: Data

    func makeUIView(context: Context) -> FLAnimatedImageView {
        let imageView = FLAnimatedImageView(frame:.zero)
        let animatedImage = FLAnimatedImage(animatedGIFData:data)
        imageView.animatedImage = animatedImage
        return imageView
    }

    func updateUIView(_ imageView: FLAnimatedImageView, context: Context) {
        let animatedImage = FLAnimatedImage(animatedGIFData:data)
        imageView.animatedImage = animatedImage
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        guard
            let width = proposal.width,
            let height = proposal.height
        else { return nil }
        return CGSize(width: width, height: height)
    }
}

//see https://www.hackingwithswift.com/books/ios-swiftui/importing-an-image-into-swiftui-using-phpickerviewcontroller
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

//see https://stackoverflow.com/a/60452526
class DocumentPickerViewController: UIDocumentPickerViewController {
    private let onDismiss: () -> Void
    private let onPick: (URL) -> ()

    init(supportedTypes: [UTType], onPick: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onPick = onPick

        super.init(forOpeningContentTypes:supportedTypes, asCopy:true)

        allowsMultipleSelection = false
        delegate = self
    }

    required init?(coder: NSCoder) {
        unreachable("init(coder:) has not been implemented")
    }
}

extension DocumentPickerViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls.first!)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onDismiss()
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {
        
    }
}

// clear button for text fields, see https://stackoverflow.com/a/58896723/3528174
struct ClearButton: ViewModifier {
    let isEditing: Bool
    @Binding var text: String
    
    public func body(content: Content) -> some View {
        HStack {
            content
                .accessibilitySortPriority(2)
            
            if isEditing, !text.isEmpty {
                Button {
                    self.text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .accessibilityLabel(Text("Clear text"))
                }
                .padding(.trailing, 8)
                .accessibilitySortPriority(1)
            }
        }
    }
}
//this extension contains the easy-access view modifier
extension View {
    /// Puts the view in an HStack and adds a clear button to the right when the text is not empty.
    func addClearButton(isEditing: Bool, text: Binding<String>) -> some View {
        modifier(ClearButton(isEditing: isEditing, text:text))
    }
}

//see https://exyte.com/blog/swiftui-tutorial-popupview-library
struct FrameGetterModifier: ViewModifier {
    @Binding var frame: CGRect
    func body(content: Content) -> some View {
        content
        .background(
            GeometryReader { proxy -> AnyView in
                let rect = proxy.frame(in: .global)
                // This avoids an infinite layout loop
                if rect.integral != self.frame.integral {
                    DispatchQueue.main.async {
                        self.frame = rect
                    }
                }
                return AnyView(EmptyView())
            }
        )
    }
}
extension View { 
    func frameGetter(_ frame: Binding<CGRect>) -> some View {
        modifier(FrameGetterModifier(frame: frame))
    }
}

struct NumberlessBadge: View {
    @Binding var notificationCount: Int
    private let size: Int
    private let inset: Int

    var badgeSize: CGFloat {
        CGFloat(integerLiteral: size)
    }

    var edgeInset: CGFloat {
        CGFloat(integerLiteral: inset)
    }

    init(_ notificationCount: Binding<Int>, size: Int = 7, inset: Int = 1) {
        self._notificationCount = notificationCount
        self.size = size
        self.inset = inset
    }

    var body: some View {
        HStack {
            Spacer()
            VStack {
                if notificationCount > 0 {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: badgeSize, height: badgeSize)
                        .tint(.red)
                        .padding(.trailing, edgeInset)
                        .padding(.top, edgeInset)
                }
                Spacer()
            }
        }
        .animation(.default, value: notificationCount)
    }
}

// //see https://stackoverflow.com/a/68291983
// struct OverflowContentViewModifier: ViewModifier {
//     @State private var contentOverflow: Bool = false
//     func body(content: Content) -> some View {
//         GeometryReader { geometry in
//             content
//             .background(
//                 GeometryReader { contentGeometry in
//                     Color.clear.onAppear {
//                         contentOverflow = contentGeometry.size.height > geometry.size.height
//                     }
//                 }
//             )
//             .wrappedInScrollView(when: contentOverflow)
//         }
//     }
// }
// 
// extension View {
//     @ViewBuilder
//     func wrappedInScrollView(when condition: Bool) -> some View {
//         if condition {
//             ScrollView {
//                 self
//             }
//         } else {
//             self
//         }
//     }
// }
// 
// extension View {
//     func scrollOnOverflow() -> some View {
//         modifier(OverflowContentViewModifier())
//     }
// }

// lazy loading of views (e.g. when used inside a NavigationLink) with the additional ability to use a closure to modify/wrap them
// see https://stackoverflow.com/a/61234030/3528174
struct LazyClosureView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    init(withClosure build: @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

// use this to wrap a view into NavigationStack, if it should be the outermost swiftui view of a new view stack
struct AddTopLevelNavigation<Content: View>: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var sizeClass: ObservableKVOWrapper<SizeClassWrapper>
    let build: () -> Content
    let delegate: SheetDismisserProtocol?
    
    init(withDelegate delegate: SheetDismisserProtocol?, to build: @autoclosure @escaping () -> Content) {
        self.build = build
        self.delegate = delegate

        let activeChats = (UIApplication.shared.delegate as! MonalAppDelegate).activeChats!
        self._sizeClass = StateObject(wrappedValue: ObservableKVOWrapper<SizeClassWrapper>(activeChats.sizeClass))
    }
    
    var body: some View {
        NavigationStack {
            build()
                .navigationBarTitleDisplayMode(.automatic)
                .navigationBarBackButtonHidden(true) // will not be shown because swiftui does not know we navigated here from UIKit
                .toolbar {
#if targetEnvironment(macCatalyst)
                    let shouldDisplayBackButton = true
#else
                    let shouldDisplayBackButton = UIUserInterfaceSizeClass(rawValue: sizeClass.horizontal) == .compact
#endif
                    if shouldDisplayBackButton {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action : {
                                //NOTE: since we can get opened from objc, we still need to support our SheetDismisserProtocol
                                if let delegate = self.delegate {
                                    delegate.dismiss()
                                } else {
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                Image(systemName: "arrow.backward")
                            }
                            .keyboardShortcut(.escape, modifiers: [])
                        }
                    }
                }
        }
    }
}

// TODO: fix those workarounds as soon as we have no storyboards anymore
struct UIKitWorkaround<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    init(withClosure build: @escaping () -> Content) {
        self.build = build
    }
    var body: some View {
        if(UIDevice.current.userInterfaceIdiom == .phone) {
            build().navigationBarTitleDisplayMode(.inline)
        } else {
#if targetEnvironment(macCatalyst)
            build().navigationBarTitleDisplayMode(.inline)
#else
            NavigationStack {
                build()
                .navigationBarTitleDisplayMode(.automatic)
            }

#endif
        }
    }
}

// properties for use in Alert
struct AlertPrompt {
    var title: Text = Text("")
    var message: Text = Text("")
    var dismissLabel: Text = Text("Close")
    var dismissCallback: monal_void_block_t? = nil
}

// properties for use in actionSheet
struct ConfirmationPrompt {
    var title: Text = Text("")
    var message: Text = Text("")
    var buttons: [ActionSheet.Button] = []
}

extension View {
    /// Applies the given transform.
    ///
    /// Useful for availability branching on view modifiers. Do not branch with any properties that may change during runtime as this will cause errors.
    /// - Parameters:
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: The view transformed by the transform.
    func applyClosure<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

public extension UIViewController {
    private struct AssociatedKeys {
        static var DisposeCallbackKey = "ml_disposeCallbackKey"
    }
    
    private class DisposeCallback : NSObject {
        let callback: monal_void_block_t
        
        init(withCallback callback: @escaping monal_void_block_t) {
            self.callback = callback
        }
        
        deinit {
            self.callback()
        }
    }
    
    @objc
    var ml_disposeCallback: monal_void_block_t {
        get {
            return withUnsafePointer(to: &AssociatedKeys.DisposeCallbackKey) { pointer in
                if let callback = (objc_getAssociatedObject(self, pointer) as? DisposeCallback)?.callback {
                    return callback
                }
                unreachable("You can't get what you did not set!")
            }
        }
        set {
            withUnsafePointer(to: &AssociatedKeys.DisposeCallbackKey) { pointer in
                objc_setAssociatedObject(self, pointer, DisposeCallback(withCallback: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

// Interfaces between ObjectiveC/Storyboards and SwiftUI
@objc
class SwiftuiInterface : NSObject {
    @objc
    func makeChatView(for contact: MLContact) -> UIViewController {
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        host.rootView = AnyView(ChatView(contact:ObservableKVOWrapper<MLContact>(contact)))
        return host
    }
    
    @objc(makeAccountPickerForContacts:andCallType:)
    func makeAccountPicker(for contacts: [MLContact], and callType: UInt) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate:delegate, to:AccountPicker(contacts:contacts, callType:MLCallType(rawValue: callType)!)))
        return host
    }
    
    @objc(makeCallScreenForCall:)
    func makeCallScreen(for call: MLCall) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(AVCallUI(delegate:delegate, call:call))
        return host
    }
    
    @objc
    func makeContactDetails(_ contact: MLContact) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate:delegate, to:ContactDetails(delegate:delegate, contact:ObservableKVOWrapper<MLContact>(contact))))
        return host
    }
    
    @objc(makeImageViewerForCurrentItem:allItems:)
    func makeImageViewerFor(currentItem:[String:AnyObject], allItems: [[String:AnyObject]]) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(MediaItemSwipeView(currentItem: currentItem, allItems: allItems))
        return host
    }
    
    @objc
    func makeOwnOmemoKeyView(_ ownContact: MLContact?) -> UIViewController {
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        if(ownContact == nil) {
            host.rootView = AnyView(UIKitWorkaround(OmemoKeysView(omemoKeys: OmemoKeysForChat(viewContact: nil))))
        } else {
            host.rootView = AnyView(UIKitWorkaround(OmemoKeysView(omemoKeys: OmemoKeysForChat(viewContact: ObservableKVOWrapper<MLContact>(ownContact!)))))
        }
        return host
    }

    @objc
    func makeChangePasswordView(for accountID: NSNumber) -> UIViewController {
        let host = UIHostingController(rootView:AnyView(EmptyView()))
            host.rootView = AnyView(ChangePassword(accountID: accountID))
        return host
    }

    @objc
    func makeAccountRegistration(_ registerData: [String:AnyObject]?) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
#if IS_QUICKSY
        host.rootView = AnyView(Quicksy_RegisterAccount(delegate:delegate))
#else
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate:delegate, to:RegisterAccount(delegate:delegate, registerData:registerData)))
#endif
        return host
    }

    @objc
    func makeServerDetailsView(for xmppAccount: xmpp) -> UIViewController {
        let host = UIHostingController(rootView:AnyView(EmptyView()))
            host.rootView = AnyView(ServerDetails(xmppAccount: xmppAccount))
        return host
    }

    @objc
    func makeBlockedUsersView(for xmppAccount: xmpp) -> UIViewController {
        let host = UIHostingController(rootView:AnyView(EmptyView()))
            host.rootView = AnyView(BlockedUsers(xmppAccount: xmppAccount))
        return host
    }

    @objc
    func makePasswordMigration(_ needingMigration: [[String:NSObject]]) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate:delegate, to:PasswordMigration(delegate:delegate, needingMigration:needingMigration)))
        return host
    }
    
    @objc(makeAddContactViewWithDismisser:)
    func makeAddContactView(dismisser: @escaping (MLContact) -> ()) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate: delegate, to: AddContactMenu(delegate: delegate, dismissWithNewContact: dismisser)))
        return host
    }
    
    @objc
    func makeAddContactView(forJid jid:String, preauthToken: String?, prefillAccount: xmpp?, andOmemoFingerprints omemoFingerprints: [NSNumber:Data]?, withDismisser dismisser: @escaping (MLContact) -> ()) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView:AnyView(EmptyView()))
        delegate.host = host
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate: delegate, to: AddContactMenu(delegate: delegate, dismissWithNewContact: dismisser, prefillJid: jid, preauthToken: preauthToken, prefillAccount: prefillAccount, omemoFingerprints: omemoFingerprints)))
        return host
    }

    @objc(makeContactsViewWithDismisser:onButton:)
    func makeContactsView(dismisser: @escaping (MLContact) -> (), button: UIBarButtonItem) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        let contactsView = ContactsView(contacts: Contacts(), delegate: delegate, dismissWithContact: dismisser)
        delegate.host = host
        host.rootView = AnyView(AddTopLevelNavigation(withDelegate: delegate, to: contactsView))
        host.modalPresentationStyle = .popover
        host.popoverPresentationController?.sourceItem = button
        host.preferredContentSize = host.sizeThatFits(in: CGSize(width: 400, height: 600))
        return host
    }

    @objc
    func makeView(name: String) -> UIViewController {
        let delegate = SheetDismisserProtocol()
        var host: UIHostingController<AnyView>? = nil
        //let host = UIHostingController(rootView:AnyView(EmptyView()))
        switch(name) { // TODO names are currently taken from the segue identifier, an enum would be nice once everything is ported to SwiftUI
            case "DebugView":
                host = UIHostingController(rootView:AnyView(UIKitWorkaround(DebugView())))
            case "WelcomeLogIn":
                host = UIHostingController(rootView:AnyView(AddTopLevelNavigation(withDelegate:delegate, to:WelcomeLogIn(delegate:delegate))))
            case "LogIn":
                host = UIHostingController(rootView:AnyView(UIKitWorkaround(WelcomeLogIn(delegate:delegate))))
            case "AdvancedLogIn":
                host = UIHostingController(rootView:AnyView(UIKitWorkaround(WelcomeLogIn(advancedMode: true, delegate: delegate))))
            case "ChatPlaceholder":
                host = UIHostingController(rootView:AnyView(ChatPlaceholder()))
            case "GeneralSettings" :
                host = UIHostingController(rootView:AnyView(UIKitWorkaround(GeneralSettings())))
            case "ActiveChatsGeneralSettings":
                host = UIHostingController(rootView:AnyView(AddTopLevelNavigation(withDelegate: delegate, to: GeneralSettings())))
            case "ActiveChatsNotificationSettings":
                host = UIHostingController(rootView:AnyView(AddTopLevelNavigation(withDelegate: delegate, to: NotificationSettings())))
            case "OnboardingView":
                host = UIHostingController(rootView:AnyView(createOnboardingView(delegate:delegate)))
            
            default:
                unreachable()
        }
        delegate.host = host!
        return host!
    }
}
