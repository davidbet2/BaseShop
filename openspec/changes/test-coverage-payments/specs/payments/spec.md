# Delta for Payments Service Tests

## ADDED Requirements

### Requirement: Payments Service Unit Tests

The payments-service MUST have unit and integration tests to verify payment functionality.

#### Scenario: POST /api/payments/create with valid data

- GIVEN a valid JWT token and valid payment data (order_id, amount, buyer_email, buyer_name)
- WHEN the user sends a POST request to /api/payments/create
- THEN the response status MUST be 201
- AND the response MUST include payment_id, order_id, amount, and payu_form_data

#### Scenario: POST /api/payments/create with missing required fields

- GIVEN a valid JWT token but missing required fields
- WHEN the user sends a POST request to /api/payments/create with incomplete data
- THEN the response status MUST be 400
- AND the response MUST include an error message describing the validation failure

#### Scenario: POST /api/payments/create without authentication

- GIVEN no JWT token
- WHEN the user sends a POST request to /api/payments/create
- THEN the response status MUST be 401
- AND the response MUST include an error message about missing token

#### Scenario: GET /api/payments/order/:orderId as owner

- GIVEN a valid JWT token for a user who owns the order
- WHEN the user sends a GET request to /api/payments/order/:orderId
- THEN the response status MUST be 200
- AND the response MUST include payment data

#### Scenario: GET /api/payments/order/:orderId as different user

- GIVEN a valid JWT token for a different user
- WHEN the user sends a GET request to /api/payments/order/:orderId they don't own
- THEN the response status MUST be 404
- AND the response MUST indicate payment not found

#### Scenario: GET /api/payments (admin only)

- GIVEN a valid JWT token with admin role
- WHEN the admin sends a GET request to /api/payments
- THEN the response status MUST be 200
- AND the response MUST include a list of payments with pagination

#### Scenario: GET /api/payments (non-admin user)

- GIVEN a valid JWT token with user role (not admin)
- WHEN the user sends a GET request to /api/payments
- THEN the response status MUST be 403
- AND the response MUST indicate insufficient permissions

#### Scenario: GET /api/payments/stats/summary (admin only)

- GIVEN a valid JWT token with admin role
- WHEN the admin sends a GET request to /api/payments/stats/summary
- THEN the response status MUST be 200
- AND the response MUST include totalPayments, byStatus, and revenue data

#### Scenario: POST /api/payments/:id/refund (admin only)

- GIVEN a valid JWT token with admin role
- AND a payment with status "approved"
- WHEN the admin sends a POST request to /api/payments/:id/refund
- THEN the response status MUST be 200
- AND the payment status MUST be updated to "refunded"

#### Scenario: POST /api/payments/:id/refund on non-approved payment

- GIVEN a valid JWT token with admin role
- AND a payment with status "pending"
- WHEN the admin sends a POST request to /api/payments/:id/refund
- THEN the response status MUST be 400
- AND the response MUST indicate that only approved payments can be refunded

### Requirement: Webhook Tests

The webhook endpoint MUST handle PayU callbacks correctly.

#### Scenario: POST /api/payments/webhook/payu with valid signature

- GIVEN a valid PayU webhook payload with correct signature
- WHEN the system receives the POST request
- THEN the payment status MUST be updated accordingly
- AND the response status MUST be 200

#### Scenario: POST /api/payments/web/payu with invalid signature

- GIVEN a PayU webhook payload with invalid signature
- WHEN the system receives the POST request
- THEN the response status MUST be 400
- AND the response MUST include an error about invalid signature

#### Scenario: POST /api/payments/webhook/payu for non-existent payment

- GIVEN a PayU webhook payload for a non-existent payment reference
- WHEN the system receives the POST request
- THEN the response status MUST be 404
- AND the response MUST indicate payment not found

### Requirement: Authentication Middleware Tests

The auth middleware MUST correctly validate tokens.

#### Scenario: Request with valid Bearer token

- GIVEN a valid JWT token in Authorization header
- WHEN the request goes through authMiddleware
- THEN req.user MUST be populated with the decoded token payload
- AND the request MUST proceed to the next middleware

#### Scenario: Request without token

- GIVEN no Authorization header
- WHEN the request goes through authMiddleware
- THEN the response status MUST be 401
- AND the response MUST include an error message about missing token

#### Scenario: Request with invalid token

- GIVEN an invalid JWT token in Authorization header
- WHEN the request goes through authMiddleware
- THEN the response status MUST be 401
- AND the response MUST include an error message about invalid token
