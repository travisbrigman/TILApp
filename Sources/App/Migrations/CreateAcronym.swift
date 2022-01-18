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
        database.schema(Acronym.v20210114.schemaName)
            .id()
            .field(Acronym.v20210114.short, .string, .required)
            .field(Acronym.v20210114.long, .string, .required)
            .field(
                Acronym.v20210114.userID,
                .uuid,
                .required,
                .references(User.v20210113.schemaName, User.v20210113.id))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Acronym.v20210114.schemaName).delete()
    }

    // 7 - Implement revert(on:) as required by Migration. You call this function when you revert your migrations. This deletes the table referenced with schema(_:).

}

extension Acronym {
    // 1
    enum v20210114 {
        // 2
        static let schemaName = "acronyms"
        // 3
        static let id = FieldKey(stringLiteral: "id")
        static let short = FieldKey(stringLiteral: "short")
        static let long = FieldKey(stringLiteral: "long")
        static let userID = FieldKey(stringLiteral: "userID")
    }
}
