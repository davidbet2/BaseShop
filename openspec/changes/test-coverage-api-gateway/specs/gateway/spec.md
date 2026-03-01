# Delta for API Gateway Tests

## ADDED Requirements

### Requirement: API Gateway Integration Tests

The API gateway MUST have integration tests to verify routing and proxy functionality.

#### Scenario: GET /health returns gateway status

- GIVEN the gateway is running
- WHEN a GET request is made to /health
- THEN the response status MUST be 200
- AND the response MUST include service: "api-gateway" and status: "running"

#### Scenario: GET /api/products proxies to products-service

- GIVEN products-service is running
- WHEN a GET request is made to /api/products through the gateway
- THEN the response status MUST be 200
- AND the response MUST contain products data

#### Scenario: GET /api/auth/login proxies to auth-service

- GIVEN auth-service is running
- WHEN a POST request is made to /api/auth/login through the gateway
- THEN the response MUST be proxied to auth-service

#### Scenario: CORS allows configured origins

- GIVEN a request from http://localhost:8080
- WHEN the request goes through CORS middleware
- THEN the response MUST include Access-Control-Allow-Origin header

#### Scenario: Rate limiting returns 429 after limit

- GIVEN more than 500 requests in 15 minutes
- WHEN another request is made
- THEN the response status MUST be 429
- AND the response MUST include an error message about rate limit

#### Scenario: Unmatched route returns 404

- GIVEN a request to a non-existent route
- WHEN the request goes through the gateway
- THEN the response status MUST be 404

#### Scenario: Proxy error returns 503

- GIVEN a downstream service is unavailable
- WHEN a request is proxied to that service
- THEN the response status MUST be 503
- AND the response MUST include an error message about service unavailability
