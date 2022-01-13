//
//  ImperialController.swift
//  
//
//  Created by Travis Brigman on 12/26/21.
//

import ImperialGoogle
import ImperialGitHub
import Vapor
import Fluent

struct ImperialController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
      guard let googleCallbackURL =
        Environment.get("GOOGLE_CALLBACK_URL") else {
          fatalError("Google callback URL not set")
      }
      try routes.oAuth(
        from: Google.self,
        authenticate: "login-google",
        callback: googleCallbackURL,
        scope: ["profile", "email"],
        completion: processGoogleLogin)
      routes.get("iOS", "login-google", use: iOSGoogleLogin)
      
      guard let githubCallbackURL =
        Environment.get("GITHUB_CALLBACK_URL") else {
          fatalError("GitHub callback URL not set")
      }
      try routes.oAuth(
        from: GitHub.self,
        authenticate: "login-github",
        callback: githubCallbackURL,
        scope: ["user:email"],
        completion: processGitHubLogin)
      
      routes.get("iOS", "login-github", use: iOSGitHubLogin)

  }
      func processGoogleLogin(request: Request, token: String)
        throws -> EventLoopFuture<ResponseEncodable> {
            // 1 - Get the user information from Google.
            try Google
              .getUser(on: request)
              .flatMap { userInfo in
                // 2 - See if the user exists in the database by looking up the email as the username.
                User
                  .query(on: request.db)
                  .filter(\.$username == userInfo.email)
                  .first()
                  .flatMap { foundUser in
                    guard let existingUser = foundUser else {
                      // 3 - If the user doesn’t exist, create a new User using the name and email from the user information from Google. Set the password to a UUID string, since you don’t need it. This ensures that no one can login to this account via a normal password login.
                        let user = User(
                          name: userInfo.name,
                          username: userInfo.email,
                          password: UUID().uuidString,
                          email: userInfo.email)
                      // 4 - Save the user and unwrap the returned future.
                        return user.save(on: request.db).flatMap {
                          request.session.authenticate(user)
                          return generateRedirect(on: request, for: user)
                        }
                    }
                    // 6 - If the user already exists, authenticate the user in the session and redirect to the home page.
                    request.session.authenticate(existingUser)
                      return generateRedirect(on: request, for: existingUser)
                  }
              }
        }
      
    func processGitHubLogin(request: Request, token: String) throws
      -> EventLoopFuture<ResponseEncodable> {
        // 1
        return try GitHub.getUser(on: request)
          .and(GitHub.getEmails(on: request))
          .flatMap { userInfo, emailInfo in
            return User.query(on: request.db)
              .filter(\.$username == userInfo.login)
              .first()
              .flatMap { foundUser in
                guard let existingUser = foundUser else {
                  // 2
                  let user = User(
                    name: userInfo.name,
                    username: userInfo.login,
                    password: UUID().uuidString,
                    email: emailInfo[0].email)
                  return user.save(on: request.db).flatMap {
                    request.session.authenticate(user)
                    return generateRedirect(on: request, for: user)
                  }
                }
                request.session.authenticate(existingUser)
                return generateRedirect(
                  on: request,
                  for: existingUser)
            }
        }
    }
      
      func iOSGoogleLogin(_ req: Request) -> Response {
        // 1 - Add an entry to the request’s session, noting that this OAuth login attempt came from iOS.
        req.session.data["oauth_login"] = "iOS"
        // 2 - Redirect to the URL you created earlier to start the OAuth flow for logging in to the website using Google.
        return req.redirect(to: "/login-google")
      }
      
      func iOSGitHubLogin(_ req: Request) -> Response {
        // 1
        req.session.data["oauth_login"] = "iOS"
        // 2
        return req.redirect(to: "/login-github")
      }
      
      // 1 - Define a new method that takes both Request and User to generate a redirect. This new method returns EventLoopFuture<ResponseEncodable>.
      func generateRedirect(on req: Request, for user: User)
        -> EventLoopFuture<ResponseEncodable> {
          let redirectURL: EventLoopFuture<String>
          // 2 - Check the request’s session data for the oauth_login flag to see if it matches the flag set in iOSGoogleLogin(_:).
          if req.session.data["oauth_login"] == "iOS" {
            do {
              // 3 - If the request is from iOS, generate a token for the user.
              let token = try Token.generate(for: user)
              // 4 - Save the token, resolve the returned future and return a redirect. This uses the tilapp scheme and returns the token as a query parameter. You’ll use this in the iOS app.
              redirectURL = token.save(on: req.db).map {
                "tilapp://auth?token=\(token.value)"
              }
            // 5 - Catch any errors thrown by generating the token and return a failed future.
            } catch {
              return req.eventLoop.future(error: error)
            }
          } else {
            // 6 - If the request is not from iOS, create a future string for the original redirect URL.
            redirectURL = req.eventLoop.future("/")
          }
          // 7 - Reset the oauth_login flag for the next session.
          req.session.data["oauth_login"] = nil
          // 8 - Resolve the future and return a redirect using the returned string.
          return redirectURL.map { url in
            req.redirect(to: url)
          }
      }
      

    
    
}

struct GoogleUserInfo: Content {
  let email: String
  let name: String
}

extension Google {
  // 1 - Add a new method to Imperial’s Google service that gets a user’s details from the Google API.
  static func getUser(on request: Request)
    throws -> EventLoopFuture<GoogleUserInfo> {
      // 2 - Set the headers for the request by adding the OAuth token to the authorization header.
      var headers = HTTPHeaders()
      headers.bearerAuthorization =
        try BearerAuthorization(token: request.accessToken())

      // 3 - Set the URL for the request — this is Google’s API to get the user’s information. This uses Vapor’s URI type, which Client requires.
      let googleAPIURL: URI =
        "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
      // 4 - Use request.client to send the request to Google. get() sends an HTTP GET request to the URL provided. Unwrap the returned future response.
      return request
        .client
        .get(googleAPIURL, headers: headers)
        .flatMapThrowing { response in
        // 5 - Ensure the response status is 200 OK.
        guard response.status == .ok else {
          // 6 - Otherwise, return to the login page if the response was 401 Unauthorized or return an error.
          if response.status == .unauthorized {
            throw Abort.redirect(to: "/login-google")
          } else {
            throw Abort(.internalServerError)
          }
        }
        // 7 - Decode the data from the response to GoogleUserInfo and return the result.
        return try response.content
          .decode(GoogleUserInfo.self)
      }
  }
}

struct GitHubUserInfo: Content {
  let name: String
  let login: String
}

struct GitHubEmailInfo: Content {
  let email: String
}

extension GitHub {
  // 1
  static func getUser(on request: Request)
    throws -> EventLoopFuture<GitHubUserInfo> {
      // 2
      var headers = HTTPHeaders()
      try headers.add(
        name: .authorization,
        value: "token \(request.accessToken())")
      headers.add(name: .userAgent, value: "vapor")

      // 3
      let githubUserAPIURL: URI = "https://api.github.com/user"
      // 4
      return request
        .client
        .get(githubUserAPIURL, headers: headers)
        .flatMapThrowing { response in
          // 5
          guard response.status == .ok else {
            // 6
            if response.status == .unauthorized {
              throw Abort.redirect(to: "/login-github")
            } else {
              throw Abort(.internalServerError)
            }
          }
          // 7
          return try response.content
            .decode(GitHubUserInfo.self)
      }
  }
    
    // 1
    static func getEmails(on request: Request) throws
      -> EventLoopFuture<[GitHubEmailInfo]> {
        // 2
        var headers = HTTPHeaders()
        try headers.add(
          name: .authorization,
          value: "token \(request.accessToken())")
        headers.add(name: .userAgent, value: "vapor")

        // 3
        let githubUserAPIURL: URI =
          "https://api.github.com/user/emails"
        return request.client
          .get(githubUserAPIURL, headers: headers)
          .flatMapThrowing { response in
            // 4
            guard response.status == .ok else {
              // 5
              if response.status == .unauthorized {
                throw Abort.redirect(to: "/login-github")
              } else {
                throw Abort(.internalServerError)
              }
            }
            // 6
            return try response.content
              .decode([GitHubEmailInfo].self)
        }
    }
}
