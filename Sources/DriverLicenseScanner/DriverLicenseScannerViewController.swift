//  Created by josh on 2020/07/23.
import AVFoundation
import UIKit

/// Conform to this delegate to get notified of key events
public protocol DriverLicenseScannerViewControllerDelegate: AnyObject {
  /// Called user taps the cancel button. Comes with a default implementation for UIViewControllers.
  /// - Warning: The viewController does not auto-dismiss. You must dismiss the viewController
  
  func driverLicenseScannerViewControllerDidCancel(_ viewController: DriverLicenseScannerViewController)
  /// Called when an error is encountered
  
  func driverLicenseScannerViewController(_ viewController: DriverLicenseScannerViewController, didErrorWith error: DriverLicenseScannerError)
  /// Called when finished successfully
  /// - Note: successful finish does not guarentee that all credit card info can be extracted
  
  func driverLicenseScannerViewController(_ viewController: DriverLicenseScannerViewController, didFinishWith card: DriverLicense)
}

public extension DriverLicenseScannerViewControllerDelegate where Self: UIViewController {
  func driverLicenseScannerViewControllerDidCancel(_ viewController: DriverLicenseScannerViewController) {
    viewController.dismiss(animated: true)
  }
}

open class DriverLicenseScannerViewController: UIViewController {
  /// public propaties
  public var titleLabelText: String = "Add DriverLicense"
  public var subtitleLabelText: String = "Line up card within the lines"
  public var cancelButtonTitleText: String = "Cancel"
  public var cancelButtonTitleTextColor: UIColor = .gray
  public var labelTextColor: UIColor = .white
  public var textBackgroundColor: UIColor = .black
  public var cameraViewDriverLicenseFrameStrokeColor: UIColor = .white
  public var cameraViewMaskLayerColor: UIColor = .black
  public var cameraViewMaskAlpha: CGFloat = 0.7
  // MARK: - Subviews and layers
  /// View representing live camera
  private lazy var cameraView = DriverLicenseCameraView(
    delegate: self,
    driverLicenseFrameStrokeColor: self.cameraViewDriverLicenseFrameStrokeColor,
    maskLayerColor: self.cameraViewMaskLayerColor,
    maskLayerAlpha: self.cameraViewMaskAlpha
  )
  /// Analyzes text data for credit card info
  private lazy var analyzer = DriverLicenseImageAnalyzer(delegate: self)
  private weak var delegate: DriverLicenseScannerViewControllerDelegate?
  /// The backgroundColor stack view that is below the camera preview view
  private var bottomStackView = UIStackView()
  private var titleLabel = UILabel()
  private var subtitleLabel = UILabel()
  private var cancelButton = UIButton(type: .system)
  // MARK: - Vision-related
  public init(delegate: DriverLicenseScannerViewControllerDelegate) {
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
  }
  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("Not implemented")
  }
  override open func viewDidLoad() {
    super.viewDidLoad()
    layoutSubviews()
    setupLabelsAndButtons()
    AVCaptureDevice.authorize { [weak self] authoriazed in
      // This is on the main thread.
      guard let strongSelf = self else {
        return
      }
      guard authoriazed else {
        strongSelf.delegate?.driverLicenseScannerViewController(strongSelf, didErrorWith: DriverLicenseScannerError(kind: .authorizationDenied, underlyingError: nil))
        return
      }
      strongSelf.cameraView.setupCamera()
    }
  }
  override open func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cameraView.setupRegionOfInterest()
  }
}

private extension DriverLicenseScannerViewController {
  @objc func cancel(_ sender: UIButton) {
    delegate?.driverLicenseScannerViewControllerDidCancel(self)
  }
  func layoutSubviews() {
    view.backgroundColor = textBackgroundColor
    // TODO: test screen rotation cameraView, cutoutView
    cameraView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cameraView)
    NSLayoutConstraint.activate([
      cameraView.topAnchor.constraint(equalTo: view.topAnchor),
      cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cameraView.heightAnchor.constraint(equalTo: cameraView.widthAnchor, multiplier: DriverLicense.heightRatioAgainstWidth, constant: 100)
    ])
    bottomStackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bottomStackView)
    NSLayoutConstraint.activate([
      bottomStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottomStackView.topAnchor.constraint(equalTo: cameraView.bottomAnchor)
    ])
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cancelButton)
    NSLayoutConstraint.activate([
      cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
    ])
    bottomStackView.axis = .vertical
    bottomStackView.spacing = 16.0
    bottomStackView.isLayoutMarginsRelativeArrangement = true
    bottomStackView.distribution = .equalSpacing
    bottomStackView.directionalLayoutMargins = .init(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0)
    let arrangedSubviews: [UIView] = [titleLabel, subtitleLabel]
    arrangedSubviews.forEach(bottomStackView.addArrangedSubview)
  }
  func setupLabelsAndButtons() {
    titleLabel.text = titleLabelText
    titleLabel.textAlignment = .center
    titleLabel.textColor = labelTextColor
    titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
    subtitleLabel.text = subtitleLabelText
    subtitleLabel.textAlignment = .center
    subtitleLabel.font = .preferredFont(forTextStyle: .title3)
    subtitleLabel.textColor = labelTextColor
    subtitleLabel.numberOfLines = 0
    cancelButton.setTitle(cancelButtonTitleText, for: .normal)
    cancelButton.setTitleColor(cancelButtonTitleTextColor, for: .normal)
    cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
  }
}

extension DriverLicenseScannerViewController: DriverLicenseCameraViewDelegate {
  internal func didCapture(image: CGImage) {
    analyzer.analyze(image: image)
  }
  internal func didError(with error: DriverLicenseScannerError) {
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.delegate?.driverLicenseScannerViewController(strongSelf, didErrorWith: error)
      strongSelf.cameraView.stopSession()
    }
  }
}

extension DriverLicenseScannerViewController: DriverLicenseImageAnalyzerProtocol {
  internal func didFinishAnalyzation(with result: Result<DriverLicense, DriverLicenseScannerError>) {
    switch result {
    case let .success(DriverLicense):
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.cameraView.stopSession()
        strongSelf.delegate?.driverLicenseScannerViewController(strongSelf, didFinishWith: DriverLicense)
      }

    case let .failure(error):
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.cameraView.stopSession()
        strongSelf.delegate?.driverLicenseScannerViewController(strongSelf, didErrorWith: error)
      }
    }
  }
}

fileprivate extension AVCaptureDevice {
  static func authorize(authorizedHandler: @escaping ((Bool) -> Void)) {
    let mainThreadHandler: ((Bool) -> Void) = { isAuthorized in
      DispatchQueue.main.async {
        authorizedHandler(isAuthorized)
      }
    }
    switch authorizationStatus(for: .video) {
    case .authorized:
      mainThreadHandler(true)

    case .notDetermined:
      requestAccess(for: .video, completionHandler: { granted in
        mainThreadHandler(granted)
      })

    default:
      mainThreadHandler(false)
    }
  }
}
