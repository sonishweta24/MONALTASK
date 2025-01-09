import UIKit

class HomeViewController: UIViewController {
    
    @IBOutlet var HomeLbl: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        HomeLbl.textAlignment = .center
        HomeLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(HomeLbl)
        NSLayoutConstraint.activate([
            HomeLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            HomeLbl.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
    }
    override func viewWillAppear(_ animated: Bool) {
   
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.animateLabelResize(label: self.HomeLbl)
                
            }
    }
    func animateLabelResize(label: UILabel) {
        let originalFrame = label.frame
        label.frame = CGRect(x: originalFrame.origin.x, y: originalFrame.origin.y, width: 0, height: originalFrame.height) // Shrink width
        UIView.animate(withDuration: 1.0) {
            label.frame = originalFrame // Animate back to original size
        }
    }

}
