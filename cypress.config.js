// cypress.config.js
module.exports = {
    e2e: {
      // Set the baseUrl to the app service (which will run Rails)
      baseUrl: 'http://app:3000', // This is the app container's URL
  
      // Optionally, set environment variables for the tests
      env: {
        test_db: {
          host: 'test-db',  // Test DB container name
          user: 'tess-test',  // DB user for test
          password: 'tess-test',  // DB password for test
          database: 'tess-test'  // Test database name
        }
      },
  
      // Other settings like timeouts, retries, etc. can be added here as well.
    }
  };
  