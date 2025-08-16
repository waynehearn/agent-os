# Tech Stack

## Context

Global tech stack defaults for Spec Agent K projects, overridable in project-specific `.agent-os/product/tech-stack.md`.

- App Framework: ASP.NET Core Web API 6.0+
- Language: C# 10.0+
- Runtime: .NET 6.0+
- ORM Alternative: Entity Framework Core (where applicable)
- Object Mapping: AutoMapper
- Validation Framework: FluentValidation
- Messaging: MassTransit with RabbitMQ
- Caching: Tag-based caching via Mozu Core
- Testing Framework: NUnit with NSubstitute and FluentAssertions
- API Documentation: Swagger/OpenAPI
- Dependency Injection: Built-in ASP.NET Core DI with Autofac modules
- Configuration: Mozu Core Configuration (cloud-based)
- Build Tool: dotnet CLI
- Package Manager: NuGet
- Container Platform: Docker with multi-stage builds
- Container Registry: Amazon ECR
- Application Hosting: Kubernetes clusters
- Hosting Region: Multi-region deployment
- Database Hosting: MongoDB Atlas/Self-hosted
- Database Backups: Automated via MongoDB tools
- Asset Storage: Amazon S3
- CDN: CloudFront
- Asset Access: Private with signed URLs
- CI/CD Platform: Jenkins Pipeline
- CI/CD Trigger: Push to develop/main branches
- Code Quality: SonarQube analysis
- Tests: Unit and Integration tests with coverage
- Health Monitoring: Custom health check endpoints (/_mzhealth)
- Production Environment: main branch
- Staging Environment: develop branch
