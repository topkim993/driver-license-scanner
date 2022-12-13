//
//  DriverLicense.swift
//  VisionOCR
//
//  Created by topkim on 2022/12/13.
//
import Foundation

/// 운전면허증
public struct DriverLicense {
  /// 이름
  public var name: String?
  // /// 면허종류
  public var licenseType: LicenseType?
  /// 면허번호
  public var licenseNumber: String?
  /// 주민번호
  public var residentNumber: String?
  /// 발급일
  public var registDate: String?
  /// 만료일
  public var expireDate: String?
}

public enum LicenseType: String {
  case typeOneLarge = "1종대형"
  case typeOneNormal = "1종보통"
  case typeTwoNormal = "2종보통"
  
  private var sortOrder: Int {
    switch self {
    case .typeOneLarge:
      return 0
    case .typeOneNormal:
      return 1
    case .typeTwoNormal:
      return 2
    }
  }
  
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    return lhs.sortOrder == rhs.sortOrder
  }
  
  public static func <(lhs: Self, rhs: Self) -> Bool {
    return lhs.sortOrder < rhs.sortOrder
  }
}
