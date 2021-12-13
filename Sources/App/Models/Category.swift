//
//  Category.swift
//
//
//  Created by Travis Brigman on 12/4/21.
//

import Fluent
import Vapor

final class Category: Model, Content {
    static let schema = "categories"
    
    @ID
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Siblings(
        through: AcronymCategoryPivot.self,
        from: \.$category,
        to: \.$acronym)
    var acronyms: [Acronym]
    
    init() {}
    
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

extension Category {
  static func addCategory(
    _ name: String,
    to acronym: Acronym,
    on req: Request
  ) -> EventLoopFuture<Void> {
    // 1 - Perform a query to search for a category with the provided name.
    return Category.query(on: req.db)
      .filter(\.$name == name)
      .first()
      .flatMap { foundCategory in
        if let existingCategory = foundCategory {
          // 2 - If the category exists, set up the relationship.
          return acronym.$categories
            .attach(existingCategory, on: req.db)
        } else {
          // 3 - If the category doesn’t exist, create a new Category object with the provided name.
          let category = Category(name: name)
          // 4 - Save the new category and unwrap the returned future.
          return category.save(on: req.db).flatMap {
            // 5 - Set up the relationship using the saved acronym.
            acronym.$categories
              .attach(category, on: req.db)
          }
        }
    }
  }
}
