//
//  AcronymCategoryPivot.swift
//  
//
//  Created by Travis Brigman on 12/4/21.
//

import Fluent
import Foundation

// 1 - Define a new object AcronymCategoryPivot that conforms to Model.
final class AcronymCategoryPivot: Model {
  static let schema = "acronym-category-pivot"
  
  // 2 - Define an id for the model. Note this is a UUID type so you must import the Foundation module.
  @ID
  var id: UUID?
  
  // 3 - Define two properties to link to the Acronym and Category. You annotate the properties with the @Parent property wrapper. A pivot record can point to only one Acronym and one Category, but each of those types can point to multiple pivots.
  @Parent(key: "acronymID")
  var acronym: Acronym
  
  @Parent(key: "categoryID")
  var category: Category
  
  // 4 - Implement the empty initializer, as required by Model.
  init() {}
  
  // 5 - Implement an initializer that takes the two models as arguments. This uses requireID() to ensure the models have an ID set.
  init(
    id: UUID? = nil,
    acronym: Acronym,
    category: Category
  ) throws {
    self.id = id
    self.$acronym.id = try acronym.requireID()
    self.$category.id = try category.requireID()
  }
}
