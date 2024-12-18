describe('Login Test', () => {
    it('logs in with valid credentials', () => {
      cy.visit('/users/sign_in'); // Visit login page
  
      cy.get('input[name=user[login]').type('admin@localhost');
      cy.get('input[name=user[password]').type('6yNgE4T51tcgYQwE');
      cy.get('button[type="submit"]').click();
  
      cy.url().should('include', '/users/'); // Adjust based on your app's behavior
      cy.contains('admin_user'); // Ensure the user is logged in
    });
  });
  