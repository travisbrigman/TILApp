//
//  WebsiteController.swift
//
//
//  Created by Travis Brigman on 12/11/21.
//

import Foundation
import Leaf
import Vapor

// 1 - Declare a new WebsiteController type that conforms to RouteCollection.
struct WebsiteController: RouteCollection {
    // 2 - Implement boot(routes:) as required by RouteCollection.
    func boot(routes: RoutesBuilder) throws {
        // 3 - Register indexHandler(_:) to process GET requests to the router’s root path, i.e., a request to /.
        routes.get(use: indexHandler)
        routes.get("acronyms", ":acronymID", use: acronymHandler)
        routes.get("users", ":userID", use: userHandler)
        routes.get("users", use: allUsersHandler)
        // 1
        routes.get("categories", use: allCategoriesHandler)
        // 2
        routes.get("categories", ":categoryID", use: categoryHandler)
        
        // 1
        routes.get("acronyms", "create", use: createAcronymHandler)
        // 2
        routes.post("acronyms", "create", use: createAcronymPostHandler)
        routes.get(
            "acronyms", ":acronymID", "edit",
            use: editAcronymHandler)
        routes.post(
            "acronyms", ":acronymID", "edit",
            use: editAcronymPostHandler)
        routes.post(
            "acronyms", ":acronymID", "delete",
            use: deleteAcronymHandler)
    }
    
    // 4 - Implement indexHandler(_:) that returns EventLoopFuture<View>.
    func indexHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 1 - Use a Fluent query to get all the acronyms from the database.
        Acronym.query(on: req.db).all().flatMap { acronyms in
            // 2 - Add the acronyms to IndexContext if there are any, otherwise set the property to nil. Leaf can check for nil in the template.
            let context = IndexContext(
                title: "Home page",
                acronyms: acronyms)
            return req.view.render("index", context)
        }
    }
    
    // 1 - Declare a new route handler, acronymHandler(_:), that returns EventLoopFuture<View>.
    func acronymHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 2 - Extract the acronym from the request’s parameters and unwrap the result. Return a 404 Not Found if there is no acronym.
        Acronym.find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { acronym in
                // 3 - Get the user for acronym and unwrap the result.
                let userFuture = acronym.$user.get(on: req.db)
                let categoriesFuture =
                  acronym.$categories.query(on: req.db).all()
                return userFuture.and(categoriesFuture)
                  .flatMap { user, categories in
                    let context = AcronymContext(
                      title: acronym.short,
                      acronym: acronym,
                      user: user,
                      categories: categories)
                    return req.view.render("acronym", context)
                }            }
    }
    
    // 1 - Define the route handler for the user page that returns EventLoopFuture<View>.
    func userHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 2 - Get the user from the request’s parameters and unwrap the future.
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                // 3 - Get the user’s acronyms using the @Children property wrapper’s project value and unwrap the future.
                user.$acronyms.get(on: req.db).flatMap { acronyms in
                    // 4 - Create a UserContext, then render user.leaf, returning the result. In this case, you’re not setting the acronyms array to nil if it’s empty. This is not required as you’re checking the count in template.
                    let context = UserContext(
                        title: user.name,
                        user: user,
                        acronyms: acronyms)
                    return req.view.render("user", context)
                }
            }
    }
    
    // 1 - Define a route handler for the “All Users” page that returns EventLoopFuture<View>.
    func allUsersHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 2 - Get the users from the database and unwrap the future.
        User.query(on: req.db)
            .all()
            .flatMap { users in
                // 3 - Create an AllUsersContext and render the allUsers.leaf template, then return the result.
                let context = AllUsersContext(
                    title: "All Users",
                    users: users)
                return req.view.render("allUsers", context)
            }
    }
    
    func allCategoriesHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 1 - Get all the categories from the database like before.
        Category.query(on: req.db).all().flatMap { categories in
            // 2 - Create an AllCategoriesContext. Notice that the context includes the query result directly, since Leaf can handle futures.
            let context = AllCategoriesContext(categories: categories)
            // 3 - Render the allCategories.leaf template with the provided context.
            return req.view.render("allCategories", context)
        }
    }
    
    func categoryHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 1 - Get the category from the request’s parameters and unwrap the returned future.
        Category.find(req.parameters.get("categoryID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { category in
                // 2 - Perform a query get all the acronyms for the category using Fluent’s helpers.
                category.$acronyms.get(on: req.db).flatMap { acronyms in
                    // 3 - Create a context for the page.
                    let context = CategoryContext(
                        title: category.name,
                        category: category,
                        acronyms: acronyms)
                    // 4 - Return a rendered view using the category.leaf template.
                    return req.view.render("category", context)
                }
            }
    }
    
    func createAcronymHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 1 - Get all the users from the database.
        User.query(on: req.db).all().flatMap { users in
            // 2 - Create a context for the template.
            let context = CreateAcronymContext(users: users)
            // 3 - Render the page using the createAcronym.leaf template.
            return req.view.render("createAcronym", context)
        }
    }
    
    func createAcronymPostHandler(_ req: Request) throws
    -> EventLoopFuture<Response> {
        // 1 - Change Content type to decode CreateAcronymFormData.
        let data = try req.content.decode(CreateAcronymFormData.self)
        let acronym = Acronym(
            short: data.short,
            long: data.long,
            userID: data.userID)
        // 2 - Use flatMap(_:) instead of map(:_) as you now return an EventLoopFuture in the closure.
        return acronym.save(on: req.db).flatMap {
            guard let id = acronym.id else {
                // 3 - If the acronym save fails, return a failed EventLoopFuture instead of throwing the error as you can’t throw inside flatMap(_:).
                return req.eventLoop
                    .future(error: Abort(.internalServerError))
            }
            // 4 - Define an array of futures to store the save operations.
            var categorySaves: [EventLoopFuture<Void>] = []
            // 5 - Loop through all the categories provided in the request and add the results of Category.addCategory(_:to:on:) to the array of futures.
            for category in data.categories ?? [] {
                categorySaves.append(
                    Category.addCategory(
                        category,
                        to: acronym,
                        on: req))
            }
            // 6 - Flatten the array to complete all the Fluent operations and transform the result to a Response. Redirect the page to the new acronym’s page.
            let redirect = req.redirect(to: "/acronyms/\(id)")
            return categorySaves.flatten(on: req.eventLoop)
                .transform(to: redirect)
        }
    }
    
    func editAcronymHandler(_ req: Request)
    -> EventLoopFuture<View> {
        // 1 - Create a future to get the acronym to edit from the request’s parameters.
        let acronymFuture = Acronym
            .find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound))
        // 2 - Create a future to get all the users from the DB.
        let userQuery = User.query(on: req.db).all()
        // 3 - Use .and(_:) to chain the futures together and flatMap(_:) to wait for both futures to complete.
        return acronymFuture.and(userQuery)
            .flatMap { acronym, users in
                // 4 - Create a context to edit the acronym, passing in all the users.
                let context = EditAcronymContext(
                    acronym: acronym,
                    users: users)
                // 5 - Render the page using the createAcronym.leaf template, the same template used for the create page.
                return req.view.render("createAcronym", context)
            }
    }
    
    func editAcronymPostHandler(_ req: Request) throws
    -> EventLoopFuture<Response> {
        // 1 - Decode the request body to CreateAcronymData.
        let updateData =
        try req.content.decode(CreateAcronymData.self)
        // 2 - Get the acronym to edit from the request’s parameters and resolve the future.
        return Acronym
            .find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                // 3 - Update the acronym with the new data.
                acronym.short = updateData.short
                acronym.long = updateData.long
                acronym.$user.id = updateData.userID
                // 4 - Ensure the ID is set, otherwise return a failed future with a 500 Internal Server Error.
                guard let id = acronym.id else {
                    let error = Abort(.internalServerError)
                    return req.eventLoop.future(error: error)
                }
                // 5 - Save the updated acronym and transform the result to redirect to the updated acronym’s page.
                let redirect = req.redirect(to: "/acronyms/\(id)")
                return acronym.save(on: req.db).transform(to: redirect)
            }
    }
    
    func deleteAcronymHandler(_ req: Request)
    -> EventLoopFuture<Response> {
        Acronym
            .find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                acronym.delete(on: req.db)
                    .transform(to: req.redirect(to: "/"))
            }
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: [Category]
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    // 1 - Define the page’s title for the template.
    let title = "All Categories"
    // 2 - Define an array of categories to display in the page.
    let categories: [Category]
}

struct CategoryContext: Encodable {
    // 1 - A title for the page; you’ll set this as the category name.
    let title: String
    // 2 - The category for the page.
    let category: Category
    // 3 - The category’s acronyms.
    let acronyms: [Acronym]
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    let users: [User]
}

struct EditAcronymContext: Encodable {
    // 1 - The title for the page: “Edit Acronym”.
    let title = "Edit Acronym"
    // 2 - The acronym to edit.
    let acronym: Acronym
    // 3 - An array of users to display in the form.
    let users: [User]
    // 4 - A flag to tell the template that the page is for editing an acronym.
    let editing = true
}

struct CreateAcronymFormData: Content {
    let userID: UUID
    let short: String
    let long: String
    let categories: [String]?
}
