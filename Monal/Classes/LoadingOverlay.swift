//
//  LoadingOverlay.swift
//  Monal
//
//  Created by Jan on 21.06.22.
//  Copyright © 2022 Monal.im. All rights reserved.
//

//data class for overlay state
class LoadingOverlayState : ObservableObject {
    @Published var enabled: Bool
    @Published var headline: AnyView
    @Published var description: AnyView
    init(enabled:Bool = false, headline:AnyView = AnyView(Text("")), description:AnyView = AnyView(Text(""))) {
        self.enabled = enabled
        self.headline = headline
        self.description = description
    }
}

//view modifier for overlay
struct LoadingOverlay: ViewModifier {
    @ObservedObject var state : LoadingOverlayState
    public func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            content
            .disabled(state.enabled == true)
            .blur(radius:(state.enabled == true ? 3 : 0))
            
            if(state.enabled == true) {
                VStack {
                    state.headline.font(.headline)
                    state.description.font(.footnote)
                    ProgressView()
                }
                .padding(20)
                .frame(minWidth: 250, minHeight: 100)
                .background(Color.secondary.colorInvert())
                .cornerRadius(20)
                .transaction { transaction in transaction.animation = nil}
            }
        }
    }
}

//this extension contains the easy-access view modifier
extension View {    
    func addLoadingOverlay(_ overlay: LoadingOverlayState) -> some View {
        modifier(LoadingOverlay(state:overlay))
    }
}

func showPromisingLoadingOverlay<T1:View, T2:View>(_ overlay: LoadingOverlayState, headlineView headline: T1, descriptionView description: T2) -> Guarantee<Void> {
    return HelperTools.wait(atLeastSeconds:1.0, for:AnyPromise(DispatchQueue.main.async(.promise) {
        overlay.headline = AnyView(headline)
        overlay.description = AnyView(description)
        overlay.enabled = true
        //only rerender ui once (not sure if this optimization is really needed, if this is missing, use @Published for member vars of state class)
        overlay.objectWillChange.send()
        //make sure to really draw the overlay on race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.250) {
            overlay.objectWillChange.send()
        }
    })).toGuarantee()
}

func showPromisingLoadingOverlay<T:StringProtocol>(_ overlay: LoadingOverlayState, headline: T, description: T = "") -> Guarantee<Void> {
    return showPromisingLoadingOverlay(overlay, headlineView:Text(headline), descriptionView:Text(description))
}

func showPromisingLoadingOverlay<T1:View, T2:View, U: Thenable>(_ overlay: LoadingOverlayState, headlineView headline: T1, descriptionView description: T2, firstlyClosure: @escaping () -> U) -> Promise<U.T> {
    return Promise { seal in
        showPromisingLoadingOverlay(overlay, headlineView: headline, descriptionView: description).done {
            let _ = firstlyClosure().done { value in
                hideLoadingOverlay(overlay)
                seal.fulfill(value)
            }.catch { error in
                hideLoadingOverlay(overlay)
                seal.reject(error)
            }
        }
    }
}

func showPromisingLoadingOverlay<T1:View, T2:View, U: PMKFinalizer>(_ overlay: LoadingOverlayState, headlineView headline: T1, descriptionView description: T2, firstlyClosure: @escaping () -> U) -> Guarantee<Void> {
    return Guarantee { seal in
        showPromisingLoadingOverlay(overlay, headlineView: headline, descriptionView: description).done {
            let _ = firstlyClosure().finally {
                hideLoadingOverlay(overlay)
                seal(())
            }
        }
    }
}

func showPromisingLoadingOverlay<T:StringProtocol, U: Thenable>(_ overlay: LoadingOverlayState, headline: T, description: T = "", firstlyClosure: @escaping () -> U) -> Promise<U.T> {
    return showPromisingLoadingOverlay(overlay, headlineView:Text(headline), descriptionView:Text(description), firstlyClosure:firstlyClosure)
}

func showPromisingLoadingOverlay<T:StringProtocol, U: PMKFinalizer>(_ overlay: LoadingOverlayState, headline: T, description: T = "", firstlyClosure: @escaping () -> U) -> Guarantee<Void> {
    return showPromisingLoadingOverlay(overlay, headlineView:Text(headline), descriptionView:Text(description), firstlyClosure:firstlyClosure)
}

func showLoadingOverlay<T1:View, T2:View>(_ overlay: LoadingOverlayState, headlineView headline: T1, descriptionView description: T2) {
    let _ = showPromisingLoadingOverlay(overlay, headlineView:headline, descriptionView:description)
}

func showLoadingOverlay<T:StringProtocol>(_ overlay: LoadingOverlayState, headline: T, description: T = "") {
    let _ = showPromisingLoadingOverlay(overlay, headline:headline, description:description)
}

func showLoadingOverlay<T1:View, T2:View, U: Thenable>(_ overlay: LoadingOverlayState, headlineView headline: T1, descriptionView description: T2, firstlyClosure: @escaping () -> U) {
    let _ = showPromisingLoadingOverlay(overlay, headlineView:headline, descriptionView:description, firstlyClosure:firstlyClosure)
}

func showLoadingOverlay<T1:View, T2:View, U: PMKFinalizer>(_ overlay: LoadingOverlayState, headlineView headline: T1, descriptionView description: T2, firstlyClosure: @escaping () -> U) {
    let _ = showPromisingLoadingOverlay(overlay, headlineView:headline, descriptionView:description, firstlyClosure:firstlyClosure)
}

func showLoadingOverlay<T:StringProtocol, U: Thenable>(_ overlay: LoadingOverlayState, headline: T, description: T = "", firstlyClosure: @escaping () -> U) {
    let _ = showPromisingLoadingOverlay(overlay, headline:headline, description:description, firstlyClosure:firstlyClosure)
}

func showLoadingOverlay<T:StringProtocol, U: PMKFinalizer>(_ overlay: LoadingOverlayState, headline: T, description: T = "", firstlyClosure: @escaping () -> U) {
    let _ = showPromisingLoadingOverlay(overlay, headline:headline, description:description, firstlyClosure:firstlyClosure)
}

func hideLoadingOverlay(_ overlay: LoadingOverlayState) {
    DispatchQueue.main.async {
        overlay.headline = AnyView(Text(""))
        overlay.description = AnyView(Text(""))
        overlay.enabled = false
        //only rerender ui once (not sure if this optimization is really needed, if this is missing, use @Published for member vars of state class)
        overlay.objectWillChange.send()
        //make sure to really draw the overlay on race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.250) {
            overlay.objectWillChange.send()
        }
    }
}

struct LoadingOverlay_Previews: PreviewProvider {
    @StateObject static var overlay1 = LoadingOverlayState(enabled:true, headline:AnyView(Text("Loading")), description:AnyView(Text("More info?")))
    @StateObject static var overlay2 = LoadingOverlayState(enabled:true, headline:AnyView(Text("Loading")), description:AnyView(HStack {
        Image(systemName: "checkmark")
        Text("Doing a lot of work...")
    }))
    static var previews: some View {
        Form {
            Text("Entry 1")
            Text("Entry 2")
            Text("Entry 3")
        }
        .addLoadingOverlay(overlay1)
        
        Form {
            Text("Entry 1")
            Text("Entry 2")
            Text("Entry 3")
        }
        .addLoadingOverlay(overlay2)
    }
}
