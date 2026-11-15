package com.ndevstudio.expensetracker;

import com.ndevstudio.expensetracker.entity.*;
import com.ndevstudio.expensetracker.repository.*;
import com.ndevstudio.expensetracker.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class AccountDeletionTest {

    @Autowired
    private MockMvc mockMvc;

    @SpyBean
    private UserRepository userRepository;

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private ExpenseRepository expenseRepository;

    @Autowired
    private InvestmentRepository investmentRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private UserService userService;

    private String basicAuthHeader(String email, String password) {
        return "Basic " + Base64.getEncoder().encodeToString((email + ":" + password).getBytes());
    }

    private User createUser(String name, String email, String rawPassword) {
        User u = new User();
        u.setName(name);
        u.setEmail(email);
        u.setPassword(passwordEncoder.encode(rawPassword));
        return userRepository.save(u);
    }

    @BeforeEach
    public void cleanDatabase() {
        reset(userRepository);
        expenseRepository.deleteAll();
        investmentRepository.deleteAll();
        categoryRepository.deleteAll();
        bookRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    public void testSuccessfulAccountDeletion() throws Exception {
        createUser("Alice", "alice@example.com", "pass123");

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("alice@example.com", "pass123")))
                .andExpect(status().isNoContent());

        assertTrue(userRepository.findByEmail("alice@example.com").isEmpty());
    }

    @Test
    public void testUnauthenticatedDeletionRequest() throws Exception {
        mockMvc.perform(delete("/api/users/delete-account"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void testCannotDeleteAnotherUserAccount() throws Exception {
        User targetUser = createUser("Victim", "victim@example.com", "victimPass");
        User attacker = createUser("Attacker", "attacker@example.com", "attackerPass");

        Book victimBook = new Book();
        victimBook.setName("Victim Ledger");
        victimBook.setUser(targetUser);
        bookRepository.save(victimBook);

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("attacker@example.com", "attackerPass"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"victim@example.com\",\"id\":" + targetUser.getId() + "}"))
                .andExpect(status().isNoContent());

        assertTrue(userRepository.findByEmail("victim@example.com").isPresent());
        assertEquals(1, bookRepository.findByUser(targetUser).size());
        assertTrue(userRepository.findByEmail("attacker@example.com").isEmpty());
    }

    @Test
    public void testDeletionOfAssociatedExpenses() throws Exception {
        User user = createUser("Bob", "bob@example.com", "pass123");

        Book book = new Book();
        book.setName("Bob Book");
        book.setUser(user);
        book = bookRepository.save(book);

        Category category = new Category();
        category.setName("Groceries");
        category.setUser(user);
        category = categoryRepository.save(category);

        Expense expense = new Expense();
        expense.setDescription("Dinner");
        expense.setAmount(50.0);
        expense.setUser(user);
        expense.setBook(book);
        expense.setCategory(category);
        expense.setDate(LocalDateTime.now());
        expenseRepository.save(expense);

        assertEquals(1, expenseRepository.findByUser(user).size());

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("bob@example.com", "pass123")))
                .andExpect(status().isNoContent());

        assertTrue(expenseRepository.findAll().isEmpty());
    }

    @Test
    public void testDeletionOfAssociatedInvestments() throws Exception {
        User user = createUser("Charlie", "charlie@example.com", "pass123");

        Investment investment = new Investment();
        investment.setDescription("Mutual Fund");
        investment.setAmount(1000.0);
        investment.setUser(user);
        investment.setDate(LocalDateTime.now());
        investmentRepository.save(investment);

        assertEquals(1, investmentRepository.findByUser(user).size());

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("charlie@example.com", "pass123")))
                .andExpect(status().isNoContent());

        assertTrue(investmentRepository.findAll().isEmpty());
    }

    @Test
    public void testDeletionOfAssociatedCategories() throws Exception {
        User user = createUser("Dana", "dana@example.com", "pass123");

        Category cat = new Category();
        cat.setName("Travel");
        cat.setUser(user);
        categoryRepository.save(cat);

        assertEquals(1, categoryRepository.findByUser(user).size());

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("dana@example.com", "pass123")))
                .andExpect(status().isNoContent());

        assertTrue(categoryRepository.findAll().isEmpty());
    }

    @Test
    public void testDeletionOfAssociatedBooks() throws Exception {
        User user = createUser("Evan", "evan@example.com", "pass123");

        Book b1 = new Book();
        b1.setName("Active Book");
        b1.setArchived(false);
        b1.setUser(user);
        bookRepository.save(b1);

        Book b2 = new Book();
        b2.setName("Archived Book");
        b2.setArchived(true);
        b2.setUser(user);
        bookRepository.save(b2);

        assertEquals(2, bookRepository.findByUser(user).size());

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("evan@example.com", "pass123")))
                .andExpect(status().isNoContent());

        assertTrue(bookRepository.findAll().isEmpty());
    }

    @Test
    public void testUserRecordDeletion() throws Exception {
        User user = createUser("Fiona", "fiona@example.com", "pass123");
        Long userId = user.getId();

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("fiona@example.com", "pass123")))
                .andExpect(status().isNoContent());

        assertTrue(userRepository.findById(userId).isEmpty());
        assertTrue(userRepository.findByEmail("fiona@example.com").isEmpty());
    }

    @Test
    public void testCrossUserRelationshipDoesNotDeleteOtherUserDataAndRollsBack() {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Book bookA = new Book();
        bookA.setName("Book of User A");
        bookA.setUser(userA);
        bookA = bookRepository.save(bookA);

        Category categoryA = new Category();
        categoryA.setName("Category of User A");
        categoryA.setUser(userA);
        categoryA = categoryRepository.save(categoryA);

        Expense expenseB = new Expense();
        expenseB.setDescription("Expense owned by User B referencing Book of A");
        expenseB.setAmount(120.0);
        expenseB.setUser(userB);
        expenseB.setBook(bookA);
        expenseB.setCategory(categoryA);
        expenseB.setDate(LocalDateTime.now());
        expenseB = expenseRepository.save(expenseB);

        Long expenseBId = expenseB.getId();

        assertThrows(Exception.class, () -> userService.deleteUserAccount("usera@example.com"));

        // User B's expense must remain intact
        assertTrue(expenseRepository.findById(expenseBId).isPresent(), "User B expense must not be deleted");

        // User A's data must not be partially deleted (rollback intact)
        assertTrue(userRepository.findByEmail("usera@example.com").isPresent(), "User A must not be deleted");
        assertTrue(bookRepository.findById(bookA.getId()).isPresent(), "User A book must not be deleted");
        assertTrue(categoryRepository.findById(categoryA.getId()).isPresent(), "User A category must not be deleted");
    }

    @Test
    public void testTransactionRollbackOnFailurePreservesAllEntityTypes() {
        User user = createUser("George", "george@example.com", "pass123");

        Book book = new Book();
        book.setName("Rollback Book");
        book.setUser(user);
        book = bookRepository.save(book);

        Category cat = new Category();
        cat.setName("Rollback Category");
        cat.setUser(user);
        cat = categoryRepository.save(cat);

        Expense expense = new Expense();
        expense.setDescription("Rollback Expense");
        expense.setAmount(200.0);
        expense.setUser(user);
        expense.setBook(book);
        expense.setCategory(cat);
        expense.setDate(LocalDateTime.now());
        expenseRepository.save(expense);

        Investment investment = new Investment();
        investment.setDescription("Rollback Investment");
        investment.setAmount(500.0);
        investment.setUser(user);
        investment.setDate(LocalDateTime.now());
        investmentRepository.save(investment);

        // Inject failure on user delete
        doThrow(new RuntimeException("Simulated failure on user deletion step"))
                .when(userRepository).delete(any(User.class));

        assertThrows(RuntimeException.class, () -> userService.deleteUserAccount("george@example.com"));

        reset(userRepository);

        // Verify all 5 entities are preserved
        assertTrue(userRepository.findByEmail("george@example.com").isPresent(), "User must be preserved");
        assertEquals(1, expenseRepository.findByUser(user).size(), "Expenses must be preserved");
        assertEquals(1, bookRepository.findByUser(user).size(), "Books must be preserved");
        assertEquals(1, categoryRepository.findByUser(user).size(), "Categories must be preserved");
        assertEquals(1, investmentRepository.findByUser(user).size(), "Investments must be preserved");
    }

    @Test
    public void testCredentialsNoLongerAuthenticateAfterDeletion() throws Exception {
        createUser("Hannah", "hannah@example.com", "secretPass");

        mockMvc.perform(get("/books/readAll")
                .header("Authorization", basicAuthHeader("hannah@example.com", "secretPass")))
                .andExpect(status().isOk());

        mockMvc.perform(delete("/api/users/delete-account")
                .header("Authorization", basicAuthHeader("hannah@example.com", "secretPass")))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/books/readAll")
                .header("Authorization", basicAuthHeader("hannah@example.com", "secretPass")))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/users/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"hannah@example.com\",\"password\":\"secretPass\"}"))
                .andExpect(status().isNotFound());
    }
}
