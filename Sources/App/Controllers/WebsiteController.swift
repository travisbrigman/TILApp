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
        let authSessionsRoutes =
            routes.grouped(User.sessionAuthenticator())
        authSessionsRoutes.get("login", use: loginHandler)
        let credentialsAuthRoutes =
            authSessionsRoutes.grouped(User.credentialsAuthenticator())
        credentialsAuthRoutes.post("login", use: loginPostHandler)
        authSessionsRoutes.post("logout", use: logoutHandler)
        authSessionsRoutes.get(use: indexHandler)
        authSessionsRoutes.get(
            "acronyms",
            ":acronymID",
            use: acronymHandler)
        authSessionsRoutes.get("users", ":userID", use: userHandler)
        authSessionsRoutes.get("users", use: allUsersHandler)
        authSessionsRoutes.get("categories", use: allCategoriesHandler)
        authSessionsRoutes.get(
            "categories",
            ":categoryID",
            use: categoryHandler)
        let protectedRoutes = authSessionsRoutes
            .grouped(User.redirectMiddleware(path: "/login"))
        protectedRoutes.get(
            "acronyms",
            "create",
            use: createAcronymHandler)
        protectedRoutes.post(
            "acronyms",
            "create",
            use: createAcronymPostHandler)
        protectedRoutes.get(
            "acronyms",
            ":acronymID",
            "edit",
            use: editAcronymHandler)
        protectedRoutes.post(
            "acronyms",
            ":acronymID",
            "edit",
            use: editAcronymPostHandler)
        protectedRoutes.post(
            "acronyms",
            ":acronymID",
            "delete",
            use: deleteAcronymHandler)
    }

    // 4 - Implement indexHandler(_:) that returns EventLoopFuture<View>.
    func indexHandler(_ req: Request)
        -> EventLoopFuture<View>
    {
        // 1 - Use a Fluent query to get all the acronyms from the database.
        Acronym.query(on: req.db).all().flatMap { acronyms in
            // 2 - Add the acronyms to IndexContext if there are any, otherwise set the property to nil. Leaf can check for nil in the template.
            // 1 - Check if the request contains an authenticated user.
            let userLoggedIn = req.auth.has(User.self)
            // 2 - Pass the result to the new flag in IndexContext.
            // 1 - See if a cookie called cookies-accepted exists. If it doesn’t, set the showCookieMessage flag to true. You can read cookies from the request and set them on a response.
            let showCookieMessage =
              req.cookies["cookies-accepted"] == nil
            // 2 - Pass the flag to IndexContext so the template knows whether to show the message.
            let context = IndexContext(
              title: "Home page",
              acronyms: acronyms,
              userLoggedIn: userLoggedIn,
              showCookieMessage: showCookieMessage)
            return req.view.render("index", context)
        }
    }

    // 1 - Declare a new route handler, acronymHandler(_:), that returns EventLoopFuture<View>.
    func acronymHandler(_ req: Request)
        -> EventLoopFuture<View>
    {
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
                    }
            }
    }

    // 1 - Define the route handler for the user page that returns EventLoopFuture<View>.
    func userHandler(_ req: Request)
        -> EventLoopFuture<View>
    {
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
        -> EventLoopFuture<View>
    {
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
        -> EventLoopFuture<View>
    {
        // 1 - Get all the categories from the database like before.
        Category.query(on: req.db).all().flatMap { categories in
            // 2 - Create an AllCategoriesContext. Notice that the context includes the query result directly, since Leaf can handle futures.
            let context = AllCategoriesContext(categories: categories)
            // 3 - Render the allCategories.leaf template with the provided context.
            return req.view.render("allCategories", context)
        }
    }

    func categoryHandler(_ req: Request)
        -> EventLoopFuture<View>
    {
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
        -> EventLoopFuture<View>
    {
        // 1 - Get all the users from the database.
        User.query(on: req.db).all().flatMap { users in
            // 2 - Create a context for the template.
                // 1 - Create a token using 16 bytes of randomly generated data, Base64 encoded.
            let token = [UInt8].random(count: 16).base64
                // 2 - Initialize a CreateAcronymContext with the created token.
            let context = CreateAcronymContext(csrfToken: token)
                // 3 - Save the token into the request’s session data under the CSRF_TOKEN key.
            req.session.data["CSRF_TOKEN"] = token
            return req.view.render("createAcronym", context)
        }
    }

    func createAcronymPostHandler(_ req: Request) throws
        -> EventLoopFuture<Response>
    {
        // 1 - Change Content type to decode CreateAcronymFormData.
        let data = try req.content.decode(CreateAcronymFormData.self)
        let user = try req.auth.require(User.self)
        let acronym = try Acronym(
          short: data.short,
          long: data.long,
          userID: user.requireID())
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
      return Acronym
        .find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          acronym.$categories.get(on: req.db)
            .flatMap { categories in
              let context = EditAcronymContext(
                acronym: acronym,
                categories: categories)
              return req.view.render("createAcronym", context)
          }
      }
    }

    func editAcronymPostHandler(_ req: Request) throws
        -> EventLoopFuture<Response>
    {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        // 1 - Change the content type the request decodes to CreateAcronymFormData.
        let updateData =
            try req.content.decode(CreateAcronymFormData.self)
        return Acronym
            .find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                acronym.short = updateData.short
                acronym.long = updateData.long
                acronym.$user.id = userID
                guard let id = acronym.id else {
                    return req.eventLoop
                        .future(error: Abort(.internalServerError))
                }
                // 2 - Use flatMap(_:) on save(on:) but return all the acronym’s categories. Note the chaining of futures instead of nesting them. This helps improve the readability of your code.
                return acronym.save(on: req.db).flatMap {
                    // 3 - Get all categories from the database.
                    acronym.$categories.get(on: req.db)
                }.flatMap { existingCategories in
                    // 4 - Create an array of category names from the categories in the database.
                    let existingStringArray = existingCategories.map {
                        $0.name
                    }

                    // 5 - Create a Set for the categories in the database and another for the categories supplied with the request.
                    let existingSet = Set<String>(existingStringArray)
                    let newSet = Set<String>(updateData.categories ?? [])

                    // 6 - Calculate the categories to add to the acronym and the categories to remove.
                    let categoriesToAdd = newSet.subtracting(existingSet)
                    let categoriesToRemove = existingSet
                        .subtracting(newSet)

                    // 7 - Create an array of category operation results.
                    var categoryResults: [EventLoopFuture<Void>] = []
                    // 8 - Loop through all the categories to add and call Category.addCategory(_:to:on:) to set up the relationship. Add each result to the results array.
                    for newCategory in categoriesToAdd {
                        categoryResults.append(
                            Category.addCategory(
                                newCategory,
                                to: acronym,
                                on: req))
                    }

                    // 9 - Loop through all the category names to remove from the acronym.
                    for categoryNameToRemove in categoriesToRemove {
                        // 10 - Get the Category object from the name of the category to remove.
                        let categoryToRemove = existingCategories.first {
                            $0.name == categoryNameToRemove
                        }
                        // 11 - If the Category object exists, use detach(_:on:) to remove the relationship and delete the pivot.
                        if let category = categoryToRemove {
                            categoryResults.append(
                                acronym.$categories.detach(category, on: req.db))
                        }
                    }

                    let redirect = req.redirect(to: "/acronyms/\(id)")
                    // 12 - Flatten all the future category results. Transform the result to redirect to the updated acronym’s page.
                    return categoryResults.flatten(on: req.eventLoop)
                        .transform(to: redirect)
                }
            }
    }

    func deleteAcronymHandler(_ req: Request)
        -> EventLoopFuture<Response>
    {
        Acronym
            .find(req.parameters.get("acronymID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { acronym in
                acronym.delete(on: req.db)
                    .transform(to: req.redirect(to: "/"))
            }
    }

    // 1 - Define a route handler for the login page that returns a future View.
    func loginHandler(_ req: Request)
        -> EventLoopFuture<View>
    {
        let context: LoginContext
        // 2 - If the request contains the error parameter and it’s true, create a context with loginError set to true.
        if let error = req.query[Bool.self, at: "error"], error {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        // 3 - Render the login.leaf template, passing in the context.
        return req.view.render("login", context)
    }

    // 1 - Define a route handler that returns EventLoopFuture<Response>.
    func loginPostHandler(
        _ req: Request
    ) -> EventLoopFuture<Response> {
        // 2 - Verify that the request has an authenticated User. You use middleware to perform the authentication.
        if req.auth.has(User.self) {
            // 3 - Redirect to the home page after the login succeeds.
            return req.eventLoop.future(req.redirect(to: "/"))
        } else {
            // 4 - If the login failed, redirect back to the login page to show an error.
            let context = LoginContext(loginError: true)
            return req
                .view
                .render("login", context)
                .encodeResponse(for: req)
        }
    }
    
    // 1 - Define a route handler that simply returns Response. There’s no asynchronous work in this method, so it doesn’t need to return a future.
    func logoutHandler(_ req: Request) -> Response {
      // 2 - Call logout(_:) on the request. This deletes the user from the session so it can’t be used to authenticate future requests.
      req.auth.logout(User.self)
      // 3 - Return a redirect to the index page.
      return req.redirect(to: "/")
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
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
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
    // 1 - The title for the page: “Edit Acronym”.
    let title = "Edit Acronym"
    // 2 - The acronym to edit.
    let acronym: Acronym
    // 4 - A flag to tell the template that the page is for editing an acronym.
    let editing = true
    let categories: [Category]
}

struct CreateAcronymFormData: Content {
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String?
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool

    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}
