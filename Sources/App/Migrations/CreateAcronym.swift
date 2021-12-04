//
//  CreateAcronym.swift
//  CreateAcronym
//
//  Created by Travis Brigman on 11/30/21.
//

import Fluent

// 1 - Define a new type, CreateAcronym that conforms to Migration.
struct CreateAcronym: Migration {
  // 2 - Implement prepare(on:) as required by Migration. You call this method when you run your migrations.
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3 - Define the table name for this model. This must match schema from the model.
    database.schema("acronyms")
      // 4 - Define the ID column in the database.
      .id()
      // 5 - Define columns for short and long. Set the column type to string and mark the columns as required. This matches the non-optional String properties in the model. The field names must match the key of the property wrapper, not the name of the property itself.
      .field("short", .string, .required)
      .field("long", .string, .required)
      .field("userID", .uuid, .required, .references("users", "id"))
      // 6 - Create the table in the database.
      .create()
  }
  
  // 7 - Implement revert(on:) as required by Migration. You call this function when you revert your migrations. This deletes the table referenced with schema(_:).
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("acronyms").delete()
  }
}
