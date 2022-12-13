//
//  DriverLicenseImageAnalyzer.swift
//
//
//  Created by topkim on 2022/12/13.
//
import Foundation
import Vision
import Reg

protocol DriverLicenseImageAnalyzerProtocol: AnyObject {
  func didFinishAnalyzation(with result: Result<DriverLicense, DriverLicenseScannerError>)
}

final class DriverLicenseImageAnalyzer {
  
  // MARK: - Init
  
  init(delegate: DriverLicenseImageAnalyzerProtocol) {
    self.delegate = delegate
  }
  
  // MARK: - Publics
  
  func analyze(image: CGImage) {
    let requestHandler = VNImageRequestHandler(
      cgImage: image,
      orientation: .up,
      options: [:]
    )
    request.recognitionLanguages = ["ko-KR", "en-US"]
    
    do {
      try requestHandler.perform([request])
    } catch {
      let e = DriverLicenseScannerError(kind: .photoProcessing, underlyingError: error)
      delegate?.didFinishAnalyzation(with: .failure(e))
      delegate = nil
    }
  }
  
  // MARK: - Privates
  
  private weak var delegate: DriverLicenseImageAnalyzerProtocol?
  
  private let skipWords = ["Drivers", "License"]
  private let nameRegex: Regex = #"[가-힣]{2,4}"#
  private let licenseNumberRegex: Regex = #"(\d{2}-\d{2}-\d{6}-\d{2})"#
  private let residentNumberRegex: Regex = #"(\d{6}-[1-4]\d{1}\d{5})"#
  private let licenseTypeRegex: Regex = #"^1종|^2종|^특수"#
  private let dateFormatRegex: Regex = #"^(\d{4}.\d{2}.\d{2})"#
  
  private var candidates = [DriverLicense]()
  private var candidateDateStrings = [String]()
  
  private lazy var request = VNRecognizeTextRequest(completionHandler: requestHandler)
  
  private lazy var requestHandler: ((VNRequest, Error?) -> Void)? = { [weak self] request, _ in
    guard let self = self else { return }
    
    guard let results = request.results as? [VNRecognizedTextObservation] else { return }
    
    let scanedStrings = self.preprocessing(recognizedTextObservations: results)
    
    let licenseResult = self.extract(texts: scanedStrings, regex: self.licenseNumberRegex)
    guard let licenseIndex = licenseResult.index,
          let licenseNumber = licenseResult.value else {
      return
    }
    
    let residentResult = self.extract(texts: scanedStrings, regex: self.residentNumberRegex)
    guard let residentIndex = residentResult.index,
          let residentNumber = residentResult.value else {
      return
    }
    
    guard let licenseType = self.extractLicenseType(texts: scanedStrings) else {
      return
    }
    
    guard let name = self.extractName(
      texts: scanedStrings,
      residentIndex: residentIndex,
      licenseIndex: licenseIndex
    ) else {
      return
    }
    
    let dates = self.extractDates(texts: scanedStrings)
    
    let candidate = DriverLicense(
      name: name,
      licenseType: licenseType,
      licenseNumber: licenseNumber,
      residentNumber: residentNumber
    )
    
    self.candidates.append(candidate)
    self.candidateDateStrings.append(contentsOf: dates)
    
    guard self.candidates.count > 10, self.candidateDateStrings.count > 2 else {
      return
    }
    
    let candidates = self.candidates
    
    let selectedName = candidates.compactMap { $0.name }.mostFrequent
    let selectedLicenseType = candidates.compactMap { $0.licenseType }.mostFrequent
    let selectedLicenseNumber = candidates.compactMap { $0.licenseNumber }.mostFrequent
    let selectedResidentNumber = candidates.compactMap { $0.residentNumber }.mostFrequent
    
    let selectedDate = self.extractRegisterExpireDate(candidateDates: self.candidateDateStrings)
    let selectedRegisterDate = selectedDate.registerDate
    let selectedExpireDate = selectedDate.expireDate
    
    let result = DriverLicense(
      name: selectedName,
      licenseType: selectedLicenseType,
      licenseNumber: selectedLicenseNumber,
      residentNumber: selectedResidentNumber,
      registDate: selectedRegisterDate,
      expireDate: selectedExpireDate
    )
    self.delegate?.didFinishAnalyzation(with: .success(result))
  }
  
  private func preprocessing(recognizedTextObservations: [VNRecognizedTextObservation]) -> [String] {
    return recognizedTextObservations
      .compactMap {
        $0.topCandidates(1).first
      }
      .filter {
        $0.confidence > 0.1
      }
      .map {
        $0.string
      }
      .map {
        $0.replacingOccurrences(of: " ", with: "")
      }
      .filter { scannedString -> Bool in
        skipWords
          .contains { skipWord in
            scannedString.lowercased().contains(skipWord.lowercased())
          }
          .not()
      }
  }
  
  private func extract(texts: [String], regex: Regex) -> (index: Int?, value: String?) {
    guard let index = texts.firstIndex(where: {
      regex.hasMatch(in: $0)
    }) else {
      return (nil, nil)
    }
    let value = texts[safe: index]
    return (index, value)
  }
  
  private func extractName(texts: [String], residentIndex: Int, licenseIndex: Int) -> String? {
    guard residentIndex - licenseIndex == 2, residentIndex > 0 else {
      return nil
    }
    let nameIndex = residentIndex - 1
    return texts[safe: nameIndex]
  }
  
  private func extractLicenseType(texts: [String]) -> LicenseType? {
    return texts
      .filter({ licenseTypeRegex.hasMatch(in: $0) })
      .compactMap(LicenseType.init)
      .sorted(by: { $0 < $1 })
      .first
  }
  
  private func extractDates(texts: [String]) -> [String] {
    return texts
      .filter({ dateFormatRegex.hasMatch(in: $0) })
      .map { $0.filter { $0.isNumber } }
      .filter { $0.count == 8 }
  }
  
  private func extractRegisterExpireDate(candidateDates: [String]) -> (registerDate: String?, expireDate: String?) {
    var candidateDateStrings = candidateDates
    
    let firstDateFreq = candidateDateStrings.mostFrequent ?? ""
    candidateDateStrings.removeAll(where: { $0 == firstDateFreq })
    let secondDateFreq = candidateDateStrings.mostFrequent ?? ""
    candidateDateStrings.removeAll(where: { $0 == firstDateFreq })
    let thirdDateFreq = candidateDateStrings.mostFrequent ?? ""
    candidateDateStrings.removeAll(where: { $0 == firstDateFreq })
    
    let resultDates = [firstDateFreq, secondDateFreq, thirdDateFreq].sorted(by: { $0 < $1 })
    let resultRegisterDate = resultDates[safe: 0]
    let resultExpireDate = resultDates[safe: 2]
    
    return (resultRegisterDate, resultExpireDate)
  }
}

fileprivate extension Bool {
  func not() -> Bool {
    return !self
  }
}

fileprivate extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

fileprivate extension Array where Element: Hashable {
  var mostFrequent: Element? {
    let countedSet = NSCountedSet(array: self)
    var mostFrequentElement: Element?
    var maxCount = 0
    for element in countedSet {
        let count = countedSet.count(for: element)
        if count > maxCount {
          mostFrequentElement = element as? Element
            maxCount = count
        }
    }
    return mostFrequentElement
  }
}
