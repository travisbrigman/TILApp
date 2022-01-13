//
//  File.swift
//  
//
//  Created by Travis Brigman on 12/3/21.
//

import Fluent

// 1 - Create a new type for the migration to create the users table in the database.
struct CreateUser: Migration {
  // 2 - Implement prepare(on:) as required by Migration.
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3 - Set up the schema for User with the name of the table as users.
    database.schema("users")
      // 4 - Create the ID column using the default properties.
      .id()
      // 5 - Create the columns for the two other properties. These are both String and required. The name of the columns match the keys defined in the property wrapper for each property.
      .field("name", .string, .required)
      .field("username", .string, .required)
      .field("password", .string, .required)
      .field("siwaIdentifier", .string)
      .unique(on: "username")
      .field("email", .string, .required)
      .unique(on: "email")
      // 6 - Create the table.
      .create()
  }
  
  // 7 - Implement revert(on:) as required by Migration. This deletes the table named users.
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("users").delete()
  }
}
