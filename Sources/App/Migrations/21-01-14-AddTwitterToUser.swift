//
//  21-01-14-AddTwitterToUser.swift
//  
//
//  Created by Travis Brigman on 1/16/22.
//

import Fluent

// 1
struct AddTwitterURLToUser: Migration {
  // 2
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3
    database.schema(User.v20210113.schemaName)
      // 4
      .field(User.v20210114.twitterURL, .string)
      // 5
      .update()
  }

  // 6
  func revert(on database: Database) -> EventLoopFuture<Void> {
    // 7
    database.schema(User.v20210113.schemaName)
      // 8
      .deleteField(User.v20210114.twitterURL)
      // 9
      .update()
  }
}
