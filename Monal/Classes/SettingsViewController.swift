import UIKit

class SettingsViewController: UIViewController {
    
    @IBOutlet var SettingLbl: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
     //   SettingLbl.text = "Welcome to Settings"
        SettingLbl.textAlignment = .center
        SettingLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(SettingLbl)
        NSLayoutConstraint.activate([
            SettingLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            SettingLbl.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
   
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.animateLabelResize(label: self.SettingLbl)
                
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

    

