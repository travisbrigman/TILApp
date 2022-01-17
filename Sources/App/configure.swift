import Fluent
import FluentPostgresDriver
import Vapor
import Leaf
import SendGrid
// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
     app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    let databaseName: String
    let databasePort: Int
    // 1
    if (app.environment == .testing) {
      databaseName = "vapor-test"
      if let testPort = Environment.get("DATABASE_PORT") {
        databasePort = Int(testPort) ?? 5433
      } else {
        databasePort = 5433
      }
    } else {
          databaseName = "vapor_database"
          databasePort = 5432
        }
    app.databases.use(.postgres(
      hostname: Environment.get("DATABASE_HOST")
        ?? "localhost",
      port: databasePort,
      username: Environment.get("DATABASE_USERNAME")
        ?? "vapor_username",
      password: Environment.get("DATABASE_PASSWORD")
        ?? "vapor_password",
      database: Environment.get("DATABASE_NAME")
        ?? databaseName
    ), as: .psql)
    
    app.migrations.add(CreateUser())
    // 1 - Add CreateAcronym to the list of migrations to run.
    app.migrations.add(CreateAcronym())
    app.migrations.add(CreateCategory())
    app.migrations.add(CreateAcronymCategoryPivot())
    app.migrations.add(CreateToken())
    app.migrations.add(AddTwitterURLToUser())
    app.migrations.add(CreateAdminUser())
    app.migrations.add(CreateResetPasswordToken())
      
    // 2 - Set the log level for the application to debug. This provides more information and enables you to see your migrations.
    app.logger.logLevel = .debug

    // 3 - Automatically run migrations and wait for the result. Fluent allows you to choose when to run your migrations. This is helpful when you need to schedule them, for example. You can use wait() here since you’re not running on an EventLoop.
    try app.autoMigrate().wait()
    app.views.use(.leaf)

    // register routes
    try routes(app)
    
    app.sendgrid.initialize()
}
