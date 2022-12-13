//
//  ViewController.swift
//  Example
//
//  Created by 김정상 on 2022/12/13.
//

import UIKit

import CreditCardScanner
import DriverLicenseScanner

class ViewController: UIViewController {
  @IBOutlet weak var resultLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  @IBAction func didTapIDScan(_ sender: Any) {
    let viewController = DriverLicenseScannerViewController(delegate: self)
    self.present(viewController, animated: true)
  }
  
  @IBAction func didTapCreditCardScan(_ sender: Any) {
    let viewController = CreditCardScannerViewController(delegate: self)
    self.present(viewController, animated: true)
  }
}

extension ViewController: CreditCardScannerViewControllerDelegate {
  func creditCardScannerViewController(
    _ viewController: CreditCardScannerViewController,
    didErrorWith error: CreditCardScannerError
  ) {
    print("error: \(error)")
    resultLabel.text = error.localizedDescription
    viewController.dismiss(animated: true)
  }

  func creditCardScannerViewController(
    _ viewController: CreditCardScannerViewController,
    didFinishWith card: CreditCard
  ) {
    print("card : \(card)")
    resultLabel.text = """
    name : \(card.name ?? "")
    number : \(card.number ?? "")
    year : \(card.expireDate?.year ?? 0)
    month : \(card.expireDate?.month ?? 0)
    """
    viewController.dismiss(animated: true)
  }
}

extension ViewController: DriverLicenseScannerViewControllerDelegate {
  func driverLicenseScannerViewController(
    _ viewController: DriverLicenseScannerViewController,
    didErrorWith error: DriverLicenseScannerError
  ) {
    print("error: \(error)")
    resultLabel.text = error.localizedDescription
    viewController.dismiss(animated: true)
  }
  
  func driverLicenseScannerViewController(
    _ viewController: DriverLicenseScannerViewController,
    didFinishWith card: DriverLicense
  ) {
    print("card : \(card)")
    resultLabel.text = """
    name : \(card.name ?? "")
    licenseType : \(card.licenseType?.rawValue ?? "")
    licenseNumber : \(card.licenseNumber ?? "")
    residentNumber : \(card.residentNumber ?? "")
    registDate : \(card.registDate ?? "")
    expireDate : \(card.expireDate ?? "")
    """
    viewController.dismiss(animated: true)
  }
}
