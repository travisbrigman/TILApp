//
//  21-01-14-MakeCategoriesUnique.swift
//  
//
//  Created by Travis Brigman on 1/17/22.
//

import Fluent

// 1
struct MakeCategoriesUnique: Migration {
  // 2
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3
    database.schema(Category.v20210113.schemaName)
      // 4
      .unique(on: Category.v20210113.name)
      // 5
      .update()
  }

  // 6
  func revert(on database: Database) -> EventLoopFuture<Void> {
    // 7
    database.schema(Category.v20210113.schemaName)
      // 8
      .deleteUnique(on: Category.v20210113.name)
      // 9
      .update()
  }
}
