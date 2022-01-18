//
//  CreateAcronymeCategoryPivot.swift
//
//
//  Created by Travis Brigman on 12/4/21.
//

import Fluent

// 1 - Define a new type, CreateAcronymCategoryPivot that conforms to Migration.
struct CreateAcronymCategoryPivot: Migration {
    // 2 - Implement prepare(on:) as required by Migration.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        // 3 - Select the table using the schema name defined for AcronymCategoryPivot.
        database.schema("acronym-category-pivot")
            // 4 - Create the ID column.
            .id()
            // 5 - Create the two columns for the two properties. These use the key provided to the property wrapper, set the type to UUID, and mark the column as required.
            .field(
                AcronymCategoryPivot.v20210113.acronymID,
                .uuid,
                .required,
                .references(
                    Acronym.v20210114.schemaName,
                    Acronym.v20210114.id,
                    onDelete: .cascade))
            .field("categoryID", .uuid, .required,
                   .references("categories", "id", onDelete: .cascade))
            // 6 - Call create() to create the table in the database.
            .create()
    }

    // 7 - Implement revert(on:) as required by Migration. This deletes the table in the database.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("acronym-category-pivot").delete()
    }
}

extension AcronymCategoryPivot {
  enum v20210113 {
    static let schemaName = "acronym-category-pivot"
    static let id = FieldKey(stringLiteral: "id")
    static let acronymID = FieldKey(stringLiteral: "acronymID")
    static let categoryID = FieldKey(stringLiteral: "categoryID")
  }
}
