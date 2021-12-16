//
//  Token.swift
//  
//
//  Created by Travis Brigman on 12/15/21.
//

import Foundation
import Vapor
import Fluent

final class Token: Model, Content {
  static let schema = "tokens"

  @ID
  var id: UUID?

  @Field(key: "value")
  var value: String

  @Parent(key: "userID")
  var user: User

  init() {}

  init(id: UUID? = nil, value: String, userID: User.IDValue) {
    self.id = id
    self.value = value
    self.$user.id = userID
  }
}

extension Token {
  // 1
  static func generate(for user: User) throws -> Token {
    // 2
    let random = [UInt8].random(count: 16).base64
    // 3
    return try Token(value: random, userID: user.requireID())
  }
}


// 1 - Conform Token to Vapor’s ModelTokenAuthenticatable protocol. This allows you to use the token with HTTP Bearer authentication.
extension Token: ModelTokenAuthenticatable {
  // 2 - Tell Vapor the key path to the value key, in this case, Token’s value projected value.
  static let valueKey = \Token.$value
  // 3 - Tell Vapor the key path to the user key, in this case, Token’s user projected value.
  static let userKey = \Token.$user
  // 4 - Tell Vapor what type the user is.
  typealias User = App.User
  // 5 - Determine if the token is valid. Return true for now, but you might add an expiry date or a revoked property to check in the future.
  var isValid: Bool {
    true
  }
}
