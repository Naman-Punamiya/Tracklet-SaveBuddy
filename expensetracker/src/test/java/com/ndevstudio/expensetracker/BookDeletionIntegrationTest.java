package com.ndevstudio.expensetracker;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.BookRepository;
import com.ndevstudio.expensetracker.repository.CategoryRepository;
import com.ndevstudio.expensetracker.repository.ExpenseRepository;
import com.ndevstudio.expensetracker.repository.InvestmentRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import com.ndevstudio.expensetracker.service.BookService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.core.io.ClassPathResource;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class BookDeletionIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @SpyBean
    private BookRepository bookRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private ExpenseRepository expenseRepository;

    @Autowired
    private InvestmentRepository investmentRepository;

    @Autowired
    private BookService bookService;

    @Autowired
    private PasswordEncoder passwordEncoder;

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
        expenseRepository.deleteAll();
        investmentRepository.deleteAll();
        categoryRepository.deleteAll();
        bookRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    public void testDeleteBookWithMultipleExpensesSucceedsAndCascades() throws Exception {
        User user = createUser("Alice", "alice@example.com", "password123");

        Book book = new Book();
        book.setName("Vacation 2026");
        book.setSubtitle("Trip to Tokyo");
        book.setUser(user);
        book = bookRepository.save(book);
        Long bookId = book.getId();

        Expense exp1 = new Expense();
        exp1.setDescription("Flight Ticket");
        exp1.setAmount(600.0);
        exp1.setDate(LocalDateTime.now());
        exp1.setUser(user);
        exp1.setBook(book);
        expenseRepository.save(exp1);

        Expense exp2 = new Expense();
        exp2.setDescription("Hotel Booking");
        exp2.setAmount(450.0);
        exp2.setDate(LocalDateTime.now());
        exp2.setUser(user);
        exp2.setBook(book);
        expenseRepository.save(exp2);

        // Pre-condition: 2 expenses exist for this book
        List<Expense> expensesBefore = expenseRepository.findByBookId(bookId);
        assertEquals(2, expensesBefore.size());

        // Perform DELETE request via endpoint
        mockMvc.perform(delete("/books/delete/" + bookId)
                .header("Authorization", basicAuthHeader("alice@example.com", "password123")))
                .andExpect(status().isOk());

        // Verify book is removed
        assertTrue(bookRepository.findById(bookId).isEmpty(), "Book should be deleted from repository");

        // Verify all associated child expenses are deleted via database cascade
        List<Expense> expensesAfter = expenseRepository.findByBookId(bookId);
        assertTrue(expensesAfter.isEmpty(), "Associated expenses should be cascade-deleted with the book");
    }

    @Test
    public void testDeleteEmptyBookSucceeds() throws Exception {
        User user = createUser("David", "david@example.com", "password123");

        Book emptyBook = new Book();
        emptyBook.setName("Empty Ledger");
        emptyBook.setSubtitle("No expenses yet");
        emptyBook.setUser(user);
        emptyBook = bookRepository.save(emptyBook);
        Long bookId = emptyBook.getId();

        // Verify book has 0 expenses
        assertEquals(0, expenseRepository.findByBookId(bookId).size());

        // Perform DELETE request
        mockMvc.perform(delete("/books/delete/" + bookId)
                .header("Authorization", basicAuthHeader("david@example.com", "password123")))
                .andExpect(status().isOk());

        // Verify book is removed
        assertTrue(bookRepository.findById(bookId).isEmpty(), "Empty book should be deleted successfully");
    }

    @Test
    public void testUserCannotDeleteAnotherUsersBook() throws Exception {
        User userAlice = createUser("Alice", "alice@example.com", "password123");
        User userBob = createUser("Bob", "bob@example.com", "secret456");

        Book aliceBook = new Book();
        aliceBook.setName("Alice Ledger");
        aliceBook.setUser(userAlice);
        aliceBook = bookRepository.save(aliceBook);
        Long bookId = aliceBook.getId();

        Expense expense = new Expense();
        expense.setDescription("Alice Expense");
        expense.setAmount(75.0);
        expense.setDate(LocalDateTime.now());
        expense.setUser(userAlice);
        expense.setBook(aliceBook);
        expenseRepository.save(expense);

        // Bob attempts to delete Alice's book
        mockMvc.perform(delete("/books/delete/" + bookId)
                .header("Authorization", basicAuthHeader("bob@example.com", "secret456")))
                .andExpect(status().isUnauthorized());

        // Verify Alice's book and expenses are completely intact
        assertTrue(bookRepository.findById(bookId).isPresent(), "Alice's book must NOT be deleted by Bob");
        assertEquals(1, expenseRepository.findByBookId(bookId).size(), "Alice's expense must remain intact");
    }

    @Test
    public void testUnrelatedBooksAndExpensesRemainUntouched() throws Exception {
        User user = createUser("Emma", "emma@example.com", "password123");

        // Book 1 (to be deleted)
        Book book1 = new Book();
        book1.setName("Book 1 - Business");
        book1.setUser(user);
        book1 = bookRepository.save(book1);
        Long book1Id = book1.getId();

        Expense b1Exp1 = new Expense();
        b1Exp1.setDescription("B1 Item 1");
        b1Exp1.setAmount(50.0);
        b1Exp1.setDate(LocalDateTime.now());
        b1Exp1.setUser(user);
        b1Exp1.setBook(book1);
        expenseRepository.save(b1Exp1);

        Expense b1Exp2 = new Expense();
        b1Exp2.setDescription("B1 Item 2");
        b1Exp2.setAmount(100.0);
        b1Exp2.setDate(LocalDateTime.now());
        b1Exp2.setUser(user);
        b1Exp2.setBook(book1);
        expenseRepository.save(b1Exp2);

        // Book 2 (unrelated, should stay intact)
        Book book2 = new Book();
        book2.setName("Book 2 - Personal");
        book2.setUser(user);
        book2 = bookRepository.save(book2);
        Long book2Id = book2.getId();

        Expense b2Exp1 = new Expense();
        b2Exp1.setDescription("B2 Item 1");
        b2Exp1.setAmount(20.0);
        b2Exp1.setDate(LocalDateTime.now());
        b2Exp1.setUser(user);
        b2Exp1.setBook(book2);
        expenseRepository.save(b2Exp1);

        Expense b2Exp2 = new Expense();
        b2Exp2.setDescription("B2 Item 2");
        b2Exp2.setAmount(35.0);
        b2Exp2.setDate(LocalDateTime.now());
        b2Exp2.setUser(user);
        b2Exp2.setBook(book2);
        expenseRepository.save(b2Exp2);

        // Delete Book 1 only
        mockMvc.perform(delete("/books/delete/" + book1Id)
                .header("Authorization", basicAuthHeader("emma@example.com", "password123")))
                .andExpect(status().isOk());

        // Verify Book 1 and its expenses are gone
        assertTrue(bookRepository.findById(book1Id).isEmpty(), "Book 1 should be deleted");
        assertTrue(expenseRepository.findByBookId(book1Id).isEmpty(), "Book 1 expenses should be deleted");

        // Verify Book 2 and all its expenses are untouched
        assertTrue(bookRepository.findById(book2Id).isPresent(), "Book 2 must remain completely intact");
        List<Expense> b2Expenses = expenseRepository.findByBookId(book2Id);
        assertEquals(2, b2Expenses.size(), "Book 2 expenses must remain completely intact");
    }

    @Test
    public void testFailureDuringDeletionRollsBackTransaction() {
        User user = createUser("Charlie", "charlie@example.com", "pass789");

        Book book = new Book();
        book.setName("Charlie Book");
        book.setUser(user);
        book = bookRepository.save(book);
        Long bookId = book.getId();

        Expense exp = new Expense();
        exp.setDescription("Charlie Expense");
        exp.setAmount(120.0);
        exp.setDate(LocalDateTime.now());
        exp.setUser(user);
        exp.setBook(book);
        expenseRepository.save(exp);

        Authentication auth = new UsernamePasswordAuthenticationToken("charlie@example.com", "pass789", Collections.emptyList());

        // Simulate database crash or runtime exception when deleting book
        doThrow(new RuntimeException("Simulated database failure during book deletion"))
                .when(bookRepository).delete(any(Book.class));

        assertThrows(RuntimeException.class, () -> {
            bookService.deleteBook(bookId, auth);
        });

        // Verify rollback: Book and Expense must both remain intact in the database
        assertTrue(bookRepository.findById(bookId).isPresent(), "Book must be preserved after rollback");
        assertEquals(1, expenseRepository.findByBookId(bookId).size(), "Expense must be preserved after rollback");
    }

    @Test
    public void testMigrationSqlFileIsValidAndReadable() throws Exception {
        ClassPathResource resource = new ClassPathResource("db/migration/V20261117_1__cascade_delete_book_expenses.sql");
        assertTrue(resource.exists(), "Migration file V20261117_1__cascade_delete_book_expenses.sql must exist on classpath");

        try (InputStream in = resource.getInputStream()) {
            String sql = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            assertTrue(sql.contains("ON DELETE CASCADE"), "Migration SQL must configure ON DELETE CASCADE");
            assertTrue(sql.contains("fk_expenses_book"), "Migration SQL must define fk_expenses_book constraint");
            assertTrue(sql.contains("idx_expenses_book_id"), "Migration SQL must create idx_expenses_book_id index");
            assertTrue(sql.contains("ALTER TABLE"), "Migration SQL must alter expenses table dynamically");
            assertTrue(sql.contains("CURRENT_SCHEMA"), "Migration SQL must restrict to current schema");
            assertTrue(sql.contains("total_cols = 1"), "Migration SQL must verify single-column relationship");
            assertTrue(sql.contains("position_in_unique_constraint"), "Migration SQL must pair columns by ordinal position");
            assertTrue(sql.contains("Migration aborted: Constraint \"fk_expenses_book\" already exists"), "Migration SQL must abort if unrelated constraint is named fk_expenses_book");
        }
    }
}
