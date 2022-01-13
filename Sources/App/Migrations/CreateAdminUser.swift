//
//  File.swift
//  
//
//  Created by Travis Brigman on 12/15/21.
//

import Foundation
import Fluent
import Vapor

// 1 - Define a new type that conforms to Migration.
struct CreateAdminUser: Migration {
  // 2 - Implement the required prepare(on:).
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3 - Create a password hash from the password. Catch any errors thrown and return a failed future.
    let passwordHash: String
    do {
      passwordHash = try Bcrypt.hash("password")
    } catch {
      return database.eventLoop.future(error: error)
    }
    // 4 - Create a new user with the name Admin, username admin and the hashed password.
      let user = User(
        name: "Admin",
        username: "admin",
        password: passwordHash,
        email: "admin@localhost.local")
    // 5 - Save the user and return.
    return user.save(on: database)
  }

  // 6 - Implement the required revert(on:).
  func revert(on database: Database) -> EventLoopFuture<Void> {
    // 7 - Query User and delete any rows where the username matches admin. As usernames must be unique, this only deletes the one admin row.
    User.query(on: database)
      .filter(\.$username == "admin")
      .delete()
  }
}
