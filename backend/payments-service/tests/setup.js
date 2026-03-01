process.env.DB_PATH = ':memory:';
process.env.JWT_SECRET = 'test-secret-key';
process.env.PAYU_IS_TEST = 'true';
process.env.INTERNAL_SERVICE_SECRET = 'test-secret';
process.env.PAYU_API_KEY = 'test-api-key';
process.env.PAYU_API_LOGIN = 'test-api-login';
process.env.PAYU_MERCHANT_ID = 'test-merchant';
process.env.PAYU_ACCOUNT_ID = 'test-account';
process.env.FRONTEND_URL = 'http://localhost:8080';
process.env.GATEWAY_URL = 'http://localhost:3000';
process.env.ORDERS_SERVICE_URL = 'http://localhost:3005';

let db;

beforeAll(async () => {
  const { initDatabase, getDb } = require('../src/database');
  await initDatabase();
  db = getDb();
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});
