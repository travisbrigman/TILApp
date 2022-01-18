//
//  User.swift
//
//
//  Created by Travis Brigman on 12/3/21.
//

import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"

    @ID
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "username")
    var username: String

    @Field(key: "password")
    var password: String

    @Children(for: \.$user)
    var acronyms: [Acronym]
    
    @OptionalField(key: User.v20210114.twitterURL)
    var twitterURL: String?
    
    @OptionalField(key: "siwaIdentifier")
    var siwaIdentifier: String?
    
    @Field(key: "email")
    var email: String
    
    @OptionalField(key: "profilePicture")
    var profilePicture: String?

    init() {}

    init(
      name: String,
      username: String,
      password: String,
      twitterURL: String? = nil,
      siwaIdentifier: String? = nil,
      email: String,
      profilePicture: String? = nil
    ) {
      self.name = name
      self.username = username
      self.password = password
        self.twitterURL = twitterURL
      self.siwaIdentifier = siwaIdentifier
      self.email = email
      self.profilePicture = profilePicture
    }

    final class Public: Content {
        var id: UUID?
        var name: String
        var username: String

        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
    
    final class PublicV2: Content {
      var id: UUID?
      var name: String
      var username: String
      var twitterURL: String?

      init(id: UUID?,
           name: String,
           username: String,
           twitterURL: String? = nil) {
        self.id = id
        self.name = name
        self.username = username
        self.twitterURL = twitterURL
      }
    }
}

extension User {
    // 1 - Define a method on User that returns User.Public.
    func convertToPublic() -> User.Public {
        // 2 - Create a public version of the current object.
        return User.Public(id: id, name: name, username: username)
    }
    
    func convertToPublicV2() -> User.PublicV2 {
      return User.PublicV2(
          id: id,
          name: name,
          username: username,
          twitterURL: twitterURL)
    }
}

// 1 - Define an extension for EventLoopFuture<User>.
extension EventLoopFuture where Value: User {
    // 2 - Define a new method that returns a EventLoopFuture<User.Public>.
    func convertToPublic() -> EventLoopFuture<User.Public> {
        // 3 - Unwrap the user contained in self.
        return map { user in
            // 4 - Convert the User object to User.Public.
            user.convertToPublic()
        }
    }
    func convertToPublicV2() -> EventLoopFuture<User.PublicV2> {
      return self.map { user in
        return user.convertToPublicV2()
      }
    }
}

// 5 - Define an extension for [User].
extension Collection where Element: User {
    // 6 - Define a new method that returns [User.Public].
    func convertToPublic() -> [User.Public] {
        // 7 - Convert all the User objects in the array to User.Public.
        return map { $0.convertToPublic() }
    }
    func convertToPublicV2() -> [User.PublicV2] {
      return self.map { $0.convertToPublicV2() }
    }
}

// 8 - Define an extension for EventLoopFuture<[User]>.
extension EventLoopFuture where Value == [User] {
    // 9 - Define a new method that returns EventLoopFuture<[User.Public]>.
    func convertToPublic() -> EventLoopFuture<[User.Public]> {
        // 10 - Unwrap the array contained in the future and use the previous extension to convert all the Users to User.Public.
        return map { $0.convertToPublic() }
    }
    
    func convertToPublicV2() -> EventLoopFuture<[User.PublicV2]> {
      return self.map { $0.convertToPublicV2() }
    }
}

// 1 - Conform User to ModelAuthenticatable. This is a protocol that allows Fluent Models to use HTTP Basic Authentication.
extension User: ModelAuthenticatable {
  // 2 - Tell Vapor which key path of User is the username.
  static let usernameKey = \User.$username
  // 3 - Tell Vapor which key path of User is the password hash.
  static let passwordHashKey = \User.$password

  // 4 - Implement verify(password:) as required by ModelAuthenticatable. Since you hash the User’s password using Bcrypt, verify the hash with Bcrypt here.
  func verify(password: String) throws -> Bool {
    try Bcrypt.verify(password, created: self.password)
  }
}


// 1 - Conform User to ModelSessionAuthenticatable. This allows the application to save and retrieve your user as part of a session.
extension User: ModelSessionAuthenticatable {}
// 2 Conform User to ModelCredentialsAuthenticatable. This allows Vapor to authenticate users with a username and password when they log in. Since you’ve already implemented the necessary properties and function for ModelCredentialsAuthenticatable in ModelAuthenticatable, there’s nothing to do here.
extension User: ModelCredentialsAuthenticatable {}
