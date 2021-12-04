//
//  Acronym.swift
//  Acronym
//
//  Created by Travis Brigman on 11/30/21.
//

import Fluent
import Vapor

// 1 - Define a class that conforms to Model
final class Acronym: Model {
    // 2 - Specify the schema as required by Model. This is the name of the table in the database.
    static let schema = "acronyms"
  
    // 3 - Define an optional id property that stores the ID of the model, if one has been set. This is annotated with Fluent’s @ID property wrapper. This tells Fluent what to use to look up the model in the database.
    @ID
    var id: UUID?
  
    // 4 - Define two String properties to hold the acronym and its definition. These use the @Field property wrapper to denote a generic database field. The key parameter is the name of the column in the database.
    @Field(key: "short")
    var short: String
  
    @Field(key: "long")
    var long: String
    
    // @Parent is another special Fluent property wrapper. It tells Fluent that this property represents the parent of a parent-child relationship. Fluent uses this to query the database. @Parent also allows you to create an Acronym using only the ID of a User, without needing a full User object. This helps avoid additional database queries.
    @Parent(key: "userID")
    var user: User
  
    // 5 - Provide an empty initializer as required by Model. Fluent uses this to initialize models returned from database queries.
    init() {}
  
    // 6 - Provide an initializer to create the model as required.
    init(id: UUID? = nil, short: String, long: String, userID: User.IDValue) { // Add a new parameter to the initializer for the user’s ID of type User.IDValue. This is a typealias defined by Model, which resolves to UUID.
        self.id = id
        self.short = short
        self.long = long
        self.$user.id = userID // Set the ID of the projected value of the user property wrapper. As discussed above, this avoids you having to perform a lookup to get the full User model to create an Acronym.
    }
}

extension Acronym: Content {}
