# C# Code Style Guide

## Context

C# specific formatting rules for Spec Agent Kibo projects following Mozu.Location patterns.

## Class Structure

### File Organization

```csharp
// 1. Using statements (grouped and sorted)
using System;
using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc;
using Mozu.Location.Contracts.Dtos;

// 2. Namespace declaration
namespace Mozu.Location.WebApi.Controllers
{
    // 3. Class declaration with attributes
    [ApiController]
    [Route("commerce/admin/locations")]
    public class LocationAdminController : ControllerBase
    {
        // 4. Private fields
        private readonly ILocationAdminHandler _locationHandler;
        
        // 5. Constructor
        public LocationAdminController(ILocationAdminHandler locationHandler)
        {
            _locationHandler = locationHandler;
        }
        
        // 6. Public methods
        // 7. Private methods
    }
}
```

### Method Structure

```csharp
[HttpGet("{locationCode}")]
public async Task<ActionResult<LocationDto>> GetLocationAsync(
    string locationCode, 
    CancellationToken cancellationToken = default)
{
    var location = await _locationHandler.GetLocationAsync(locationCode, cancellationToken);
    return Ok(location);
}
```

## Mozu.Location Architecture Patterns

### Repository Pattern

Interfaces and their implementation class can be in the same file named for the implemenation class when the name of the implementation
class is the same as the interface with the exception of the interface being prefixed with and "I".

```csharp
public interface ILocationRepository
{
    Task<Location> GetAsync(string locationCode, CancellationToken cancellationToken = default);
    Task<PagedCollection<Location>> GetPagedAsync(LocationFilter filter, int startIndex, int pageSize);
}

public class LocationRepository : MongoRepositoryBase<Location>, ILocationRepository
{
    public LocationRepository(IMongoClient mongoClient) : base(mongoClient) { }
    
    public async Task<Location> GetAsync(string locationCode, CancellationToken cancellationToken = default)
    {
        var filter = FilterBuilder.Eq(x => x.LocationCode, locationCode);
        return await GetSingleAsync(filter, cancellationToken);
    }
}
```

### Handler Pattern

```csharp
public interface ILocationAdminHandler
{
    Task<LocationDto> GetLocationAsync(string locationCode, CancellationToken cancellationToken = default);
}

public class LocationAdminHandler : ILocationAdminHandler
{
    private readonly ILocationRepository _locationRepository;
    private readonly IMapper _mapper;
    
    public LocationAdminHandler(ILocationRepository locationRepository, IMapper mapper)
    {
        _locationRepository = locationRepository;
        _mapper = mapper;
    }
    
    public async Task<LocationDto> GetLocationAsync(string locationCode, CancellationToken cancellationToken = default)
    {
        var location = await _locationRepository.GetAsync(locationCode, cancellationToken);
        return _mapper.Map<LocationDto>(location);
    }
}
```

### Validation Pattern

```csharp
public class CreateLocationRequestValidator : AbstractValidator<CreateLocationRequest>
{
    public CreateLocationRequestValidator()
    {
        RuleFor(x => x.LocationCode)
            .NotEmpty()
            .MaximumLength(50);
            
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(200);
    }
}
```

### Exception Handling and Localized Error Messages Pattern

  When implementing error handling in this codebase, follow these guidelines:
  
- Never catch and convert to ActionResult unless absolutely necessary
- Let exceptions bubble up to the framework
- Don't use try-catch in controllers for business logic exceptions
- Use specific exception types that match the error condition
- Always include localized error details for user-facing errors
- Include relevant context in MessageParameters

#### 1. Use Localized Exceptions for Business Rule Violations

- **Use Mozu.Core Vae* Exceptions, Not ASP.NET ActionResults**
  The codebase follows a **domain-first exception pattern** rather than controller-level error handling:

  **❌ Avoid ASP.NET return types for business logic errors:**
  
  ```csharp
  // DON'T do this - puts business logic in controller layer
  if (location.Code == null)
  {
      return BadRequest("Location code is required");
  }
  ```

  ```csharp
  ✅ Use Mozu.Core exceptions with localization:
  // DO this - keeps business logic in domain layer

  if (location.Code == null)
  {
      var localizedAdditionalErrorDetails = new LocalizedAdditionalErrorDetails
      {
          MessageKey = "locationCodeRequired"
      };
      throw new VaeMissingOrInvalidParameterException("locationCode", localizedAdditionalErrorDetails);
  }
  ```

##### Benefits of Mozu.Core Exception Pattern

- Separation of Concerns: Business rules stay in domain/handler layers, not controllers
- Consistent Error Handling: Framework automatically converts exceptions to appropriate HTTP responses
- Localization Support: Built-in support for multi-language error messages
- Structured Error Data: Exceptions carry structured error information, not just strings
- Framework Integration: Mozu.Core middleware handles exception-to-HTTP-response conversion
- Audit Logging: Framework can automatically log exceptions with context
- Client Consistency: All clients receive consistent error response format

1. Exception-to-HTTP Response Mapping

   The Mozu.Core framework automatically maps exceptions to HTTP responses:

   | Exception Type                        | HTTP Status      | Usage                                         |
   | ------------------------------------- | ---------------- | --------------------------------------------- |
   | VaeMissingOrInvalidParameterException | 400 Bad Request  | Invalid input parameters, validation failures |
   | VaeValidationConflictException        | 409 Conflict     | Business rule violations, data conflicts      |
   | VaeItemNotFoundException              | 404 Not Found    | Resource not found                            |
   | VaeUnauthorizedException              | 401 Unauthorized | Authentication failures                       |
   | VaeForbiddenException                 | 403 Forbidden    | Authorization failures                        |

2. Domain-Driven Error Handling

    ```csharp
    // In Domain Handlers - throw exceptions for business rules
    public async Task<Location> UpdateLocationAsync(string locationCode, Location location)
    {
        var existingLocation = await _locationRepo.GetLocationAsync(locationCode);
        if (existingLocation == null)
        {
            var localizedAdditionalErrorDetails = new LocalizedAdditionalErrorDetails
            {
                MessageKey = "locationNotFound",
                MessageParameters = new List<string> { locationCode }
            };
            throw new VaeItemNotFoundException(localizedAdditionalErrorDetails);
        }

        // Business logic continues...
    }

    // In Controllers - let exceptions bubble up
    [HttpPut("{locationCode}")]
    public async Task<ActionResult<Location>> UpdateLocation(string locationCode, Location location)
    {
        // No try-catch needed - framework handles exceptions
        var updatedLocation = await _locationHandler.UpdateLocationAsync(locationCode, location);
        return Ok(updatedLocation.ToContract());
    }
    ```

3. When to Use Return Types vs Exceptions

    Use ActionResult return types for:
   - Successful operations (Ok(), Created(), NoContent())
   - Non-exceptional flow control
   - HTTP-specific concerns (caching headers, etc.)

    Use Mozu.Core exceptions for:
   - All error conditions
   - Business rule violations
   - Input validation failures
   - Resource not found scenarios
   - Any condition that should stop processing

#### 2. Localized Error Message

  ```csharp
  var localizedAdditionalErrorDetails = new LocalizedAdditionalErrorDetails
  {
      MessageKey = "messageKeyFromResourceFile",
      MessageParameters = new List<string> { "parameter1", "parameter2" }  // Optional
  };
  throw new VaeMissingOrInvalidParameterException("parameterName", localizedAdditionalErrorDetails);
  ```

#### 3. Resource File Management

- English (default): Mozu.Location.WebApi/LangResources/Exceptions.resx
- French: Mozu.Location.WebApi/LangResources/Exceptions.fr.resx
- Naming Convention: Use descriptive camelCase keys (e.g., patchDocumentCannotBeNull)
- Message Format: Support parameter substitution using {0}, {1}, etc.

#### 4. Resource File Entry Format

```xml
  <data name="EXCEPTION_TYPE.additionalErrorDetails.messageKey" xml:space="preserve">
      <value>Error message with {0} parameters</value>
  </data>
```

  Examples:

- MISSING_OR_INVALID_PARAMETER.additionalErrorDetails.patchDocumentCannotBeNull
- VALIDATION_CONFLICT.additionalErrorDetails.multipleLocationTypesNotAllowed

#### 5. When to Use Exceptions vs Validation Results

- Exceptions: Business rule violations, security issues, critical validation failures
- Validation Results: Input format validation, preliminary checks that should return BadRequest
- Controller Pattern: Convert validation results to exceptions when they represent business rule violations

#### 6. Required Translations

- Always add both English and French translations
- French translations should be natural and grammatically correct
- Test both languages if possible

#### 7. Example Implementation

```csharp
  // In handlers/validators
  if (businessRuleViolated)
  {
      var localizedAdditionalErrorDetails = new LocalizedAdditionalErrorDetails
      {
          MessageKey = "businessRuleViolationKey",
          MessageParameters = new List<string> { violatedValue }
      };
      throw new VaeValidationConflictException(localizedAdditionalErrorDetails);
  }

  // In controllers for parameter validation
  if (parameter == null)
  {
      var localizedAdditionalErrorDetails = new LocalizedAdditionalErrorDetails
      {
          MessageKey = "parameterCannotBeNull"
      };
      throw new VaeMissingOrInvalidParameterException("parameterName", localizedAdditionalErrorDetails);
  }
  ```

#### 8. Testing Localized Messages

- Build solution after adding resource entries to verify compilation
- Verify resource files are properly formatted XML
- Test exception scenarios to ensure proper localization

  7. Framework Benefits

  By using Mozu.Core exceptions, you get:
- Automatic HTTP status code mapping
- Consistent error response format across all APIs
- Built-in localization support
- Integration with audit logging
- Proper error correlation IDs
- Client SDK error handling support

## Formatting Rules

### Braces and Indentation

- Always use braces, even for single statements
- Place opening braces on new lines (Allman style)
- Use 4 spaces for indentation
- Align switch case statements with switch

### Line Length and Wrapping

- Maximum line length: 100 characters (as per CLAUDE.md)
- Break long parameter lists across multiple lines
- Align parameters when wrapping

```csharp
public async Task<ActionResult<LocationDto>> CreateLocationAsync(
    CreateLocationRequest request,
    CancellationToken cancellationToken = default)
{
    // Implementation
}
```

### Spacing

- One space after control flow keywords: `if (`, `for (`, `while (`
- No space between method name and parentheses: `GetLocation()`
- Space around operators: `x + y`, `x == y`
- No trailing whitespace

### Using Statements

- Group using statements by namespace hierarchy
- Remove unused using statements
- Use global using for common namespaces in .NET 6+ projects

### Async/Await

- Always use `async`/`await` for asynchronous operations
- Include `CancellationToken` parameters with default values
- Use `ConfigureAwait(false)` in library code

```csharp
public async Task<Location> GetLocationAsync(string locationCode, CancellationToken cancellationToken = default)
{
    return await _repository.GetAsync(locationCode, cancellationToken).ConfigureAwait(false);
}
```

### LINQ

- Use method syntax for simple operations
- Use query syntax for complex operations with multiple clauses
- Prefer explicit type declarations for clarity

### Exception Handling

- Use specific exception types
- Include meaningful error messages
- Don't catch and ignore exceptions

```csharp
public async Task<Location> GetLocationAsync(string locationCode)
{
    if (string.IsNullOrWhiteSpace(locationCode))
    {
        throw new ArgumentException("Location code cannot be null or empty", nameof(locationCode));
    }
    
    var location = await _repository.GetAsync(locationCode);
    if (location == null)
    {
        throw new LocationNotFoundException($"Location with code '{locationCode}' not found");
    }
    
    return location;
}
```

## Documentation

### XML Documentation

- Document public APIs with XML comments
- Include parameter descriptions and return value information
- Use `<see cref=""/>` for references to other types

```csharp
/// <summary>
/// Retrieves a location by its unique location code.
/// </summary>
/// <param name="locationCode">The unique identifier for the location.</param>
/// <param name="cancellationToken">Token to cancel the operation.</param>
/// <returns>The location information if found.</returns>
/// <exception cref="ArgumentException">Thrown when locationCode is null or empty.</exception>
/// <exception cref="LocationNotFoundException">Thrown when the location is not found.</exception>
public async Task<LocationDto> GetLocationAsync(string locationCode, CancellationToken cancellationToken = default)
```

### Code Comments

- Explain business logic and complex algorithms
- Don't comment obvious code
- Keep comments up-to-date with code changes
- Use TODO comments for temporary code that needs attention

## Testing Patterns

### Unit Test Structure

```csharp
[TestFixture]
public class LocationAdminHandlerTests
{
    private LocationAdminHandler _handler;
    private ILocationRepository _locationRepository;
    private IMapper _mapper;
    
    [SetUp]
    public void SetUp()
    {
        _locationRepository = Substitute.For<ILocationRepository>();
        _mapper = Substitute.For<IMapper>();
        _handler = new LocationAdminHandler(_locationRepository, _mapper);
    }
    
    [Test]
    public async Task GetLocationAsync_ValidLocationCode_ReturnsLocation()
    {
        // Arrange
        var locationCode = "STORE001";
        var location = new Location { LocationCode = locationCode };
        var locationDto = new LocationDto { LocationCode = locationCode };
        
        _locationRepository.GetAsync(locationCode, Arg.Any<CancellationToken>())
            .Returns(location);
        _mapper.Map<LocationDto>(location).Returns(locationDto);
        
        // Act
        var result = await _handler.GetLocationAsync(locationCode);
        
        // Assert
        result.Should().NotBeNull();
        result.LocationCode.Should().Be(locationCode);
    }
}
```

### Integration Test Structure

```csharp
[TestFixture]
public class LocationAdminControllerIntegrationTests : IntegrationTestBase
{
    [Test]
    public async Task GetLocation_ExistingLocation_ReturnsOk()
    {
        // Arrange
        var locationCode = "STORE001";
        await SeedLocationAsync(locationCode);
        
        // Act
        var response = await Client.GetAsync($"/commerce/admin/locations/{locationCode}");
        
        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        var location = JsonSerializer.Deserialize<LocationDto>(content);
        location.LocationCode.Should().Be(locationCode);
    }
}
```
