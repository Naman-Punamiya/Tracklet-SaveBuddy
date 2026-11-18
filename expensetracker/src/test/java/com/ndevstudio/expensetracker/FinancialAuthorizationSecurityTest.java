package com.ndevstudio.expensetracker;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.BookRepository;
import com.ndevstudio.expensetracker.repository.CategoryRepository;
import com.ndevstudio.expensetracker.repository.ExpenseRepository;
import com.ndevstudio.expensetracker.repository.InvestmentRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.Base64;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class FinancialAuthorizationSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
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
    public void testUserAReadAllReturnsOnlyUserAExpenses() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Expense expA1 = new Expense();
        expA1.setDescription("UserA Expense 1");
        expA1.setAmount(100.0);
        expA1.setUser(userA);
        expA1.setDate(LocalDateTime.now());
        expenseRepository.save(expA1);

        Expense expA2 = new Expense();
        expA2.setDescription("UserA Expense 2");
        expA2.setAmount(200.0);
        expA2.setUser(userA);
        expA2.setDate(LocalDateTime.now());
        expenseRepository.save(expA2);

        Expense expB1 = new Expense();
        expB1.setDescription("UserB Secret Expense");
        expB1.setAmount(999.0);
        expB1.setUser(userB);
        expB1.setDate(LocalDateTime.now());
        expenseRepository.save(expB1);

        MvcResult result = mockMvc.perform(get("/expenses/readAll")
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode responseArray = objectMapper.readTree(result.getResponse().getContentAsString());
        assertTrue(responseArray.isArray());
        assertEquals(2, responseArray.size());

        for (JsonNode item : responseArray) {
            String desc = item.get("description").asText();
            assertTrue(desc.startsWith("UserA"), "Should only contain UserA expenses");
            assertNotEquals("UserB Secret Expense", desc);
        }
    }

    @Test
    public void testUserACannotReadUserBBookExpenses() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Book bookB = new Book();
        bookB.setName("UserB Private Book");
        bookB.setUser(userB);
        bookB = bookRepository.save(bookB);

        Expense expB = new Expense();
        expB.setDescription("UserB Expense in Book");
        expB.setAmount(50.0);
        expB.setBook(bookB);
        expB.setUser(userB);
        expB.setDate(LocalDateTime.now());
        expenseRepository.save(expB);

        mockMvc.perform(get("/expenses/book/" + bookB.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andExpect(status().isNotFound());
    }

    @Test
    public void testUserACannotUpdateUserBExpense() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Expense expB = new Expense();
        expB.setDescription("Original UserB Expense");
        expB.setAmount(50.0);
        expB.setUser(userB);
        expB.setDate(LocalDateTime.now());
        expB = expenseRepository.save(expB);

        mockMvc.perform(put("/expenses/edit/" + expB.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"amount\":99999.0,\"description\":\"Hacked Expense\",\"credit\":false}"))
                .andExpect(status().isNotFound());

        Expense check = expenseRepository.findById(expB.getId()).orElseThrow();
        assertEquals("Original UserB Expense", check.getDescription());
        assertEquals(50.0, check.getAmount());
    }

    @Test
    public void testUserACannotDeleteUserBExpense() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Expense expB = new Expense();
        expB.setDescription("UserB Expense to preserve");
        expB.setAmount(75.0);
        expB.setUser(userB);
        expB.setDate(LocalDateTime.now());
        expB = expenseRepository.save(expB);

        mockMvc.perform(delete("/expenses/delete/" + expB.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andExpect(status().isNotFound());

        assertTrue(expenseRepository.findById(expB.getId()).isPresent());
    }

    @Test
    public void testUserACannotCreateExpenseReferencingUserBBook() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Book bookB = new Book();
        bookB.setName("UserB Private Book");
        bookB.setUser(userB);
        bookB = bookRepository.save(bookB);

        String payload = "{\"amount\":100.0,\"description\":\"Attempted Cross-User Expense\",\"book\":{\"id\":" + bookB.getId() + "}}";

        mockMvc.perform(post("/expenses/create")
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(payload))
                .andExpect(status().isBadRequest());

        List<Expense> expenses = expenseRepository.findByBookId(bookB.getId());
        assertTrue(expenses.isEmpty(), "No expense should be linked to User B's book");
    }

    @Test
    public void testUserACannotCreateExpenseReferencingUserBCategory() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Category catB = new Category();
        catB.setName("UserB Category");
        catB.setUser(userB);
        catB = categoryRepository.save(catB);

        String payload = "{\"amount\":100.0,\"description\":\"Attempted Cross-Category Expense\",\"category\":{\"id\":" + catB.getId() + "}}";

        mockMvc.perform(post("/expenses/create")
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(payload))
                .andExpect(status().isBadRequest());

        List<Expense> expenses = expenseRepository.findByCategory(catB);
        assertTrue(expenses.isEmpty(), "No expense should be linked to User B's category");
    }

    @Test
    public void testExpenseEditingCannotIntroduceCrossUserBookOrCategoryReferences() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        Book bookA = new Book();
        bookA.setName("UserA Book");
        bookA.setUser(userA);
        bookA = bookRepository.save(bookA);

        Category catA = new Category();
        catA.setName("UserA Category");
        catA.setUser(userA);
        catA = categoryRepository.save(catA);

        Expense expA = new Expense();
        expA.setDescription("Legitimate UserA Expense");
        expA.setAmount(30.0);
        expA.setBook(bookA);
        expA.setCategory(catA);
        expA.setUser(userA);
        expA.setDate(LocalDateTime.now());
        expA = expenseRepository.save(expA);

        Book bookB = new Book();
        bookB.setName("UserB Book");
        bookB.setUser(userB);
        bookB = bookRepository.save(bookB);

        Category catB = new Category();
        catB.setName("UserB Category");
        catB.setUser(userB);
        catB = categoryRepository.save(catB);

        // Attempt injecting UserB category
        mockMvc.perform(put("/expenses/edit/" + expA.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"amount\":35.0,\"description\":\"Updated\",\"category\":{\"id\":" + catB.getId() + "}}"))
                .andExpect(status().isBadRequest());

        // Attempt injecting UserB book
        mockMvc.perform(put("/expenses/edit/" + expA.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"amount\":35.0,\"description\":\"Updated\",\"book\":{\"id\":" + bookB.getId() + "}}"))
                .andExpect(status().isBadRequest());

        Expense check = expenseRepository.findById(expA.getId()).orElseThrow();
        assertEquals(bookA.getId(), check.getBook().getId());
        assertEquals(catA.getId(), check.getCategory().getId());
    }

    @Test
    public void testUserACannotRetrieveUserBUserRecord() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");
        User userB = createUser("UserB", "userb@example.com", "passB");

        mockMvc.perform(get("/api/users/" + userB.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andExpect(status().isNotFound());

        MvcResult ownResult = mockMvc.perform(get("/api/users/" + userA.getId())
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode ownUserJson = objectMapper.readTree(ownResult.getResponse().getContentAsString());
        assertEquals("usera@example.com", ownUserJson.get("email").asText());
        assertFalse(ownUserJson.has("password"), "User record must never serialize password");
    }

    @Test
    public void testGlobalUserListingIsUnavailable() throws Exception {
        createUser("UserA", "usera@example.com", "passA");

        // Global listing should return 404 or 405 (endpoint removed)
        MvcResult result = mockMvc.perform(get("/api/users")
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andReturn();

        int status = result.getResponse().getStatus();
        assertTrue(status == 404 || status == 405, "Global user listing must be unavailable (404 or 405), got: " + status);
    }

    @Test
    public void testRegistrationAndLoginResponsesDoNotContainPasswordHashes() throws Exception {
        // Test Registration response
        String registerPayload = "{\"name\":\"Alice\",\"email\":\"alice@registration-test.com\",\"password\":\"SuperSecret123!\"}";
        MvcResult regResult = mockMvc.perform(post("/api/users/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(registerPayload))
                .andExpect(status().isCreated())
                .andReturn();

        String regResponseBody = regResult.getResponse().getContentAsString();
        JsonNode regJson = objectMapper.readTree(regResponseBody);
        assertFalse(regJson.has("password"), "Registration response must not contain password field");
        assertFalse(regResponseBody.contains("SuperSecret123!"), "Registration response must not leak plaintext password");
        assertFalse(regResponseBody.contains("$2a$"), "Registration response must not leak BCrypt hash");

        // Test Login response
        String loginPayload = "{\"email\":\"alice@registration-test.com\",\"password\":\"SuperSecret123!\"}";
        MvcResult loginResult = mockMvc.perform(post("/api/users/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginPayload))
                .andExpect(status().isOk())
                .andReturn();

        String loginResponseBody = loginResult.getResponse().getContentAsString();
        JsonNode loginJson = objectMapper.readTree(loginResponseBody);
        assertFalse(loginJson.has("password"), "Login response must not contain password field");
        assertFalse(loginResponseBody.contains("SuperSecret123!"), "Login response must not leak plaintext password");
        assertFalse(loginResponseBody.contains("$2a$"), "Login response must not leak BCrypt hash");
    }

    @Test
    public void testUserACanCreateAndEditOwnExpenseSuccessfully() throws Exception {
        User userA = createUser("UserA", "usera@example.com", "passA");

        Book bookA = new Book();
        bookA.setName("UserA Ledger");
        bookA.setUser(userA);
        bookA = bookRepository.save(bookA);

        Category catA = new Category();
        catA.setName("UserA Groceries");
        catA.setUser(userA);
        catA = categoryRepository.save(catA);

        String createPayload = "{\"amount\":45.5,\"description\":\"Lunch\",\"book\":{\"id\":" + bookA.getId() + "},\"category\":{\"id\":" + catA.getId() + "}}";
        MvcResult createResult = mockMvc.perform(post("/expenses/create")
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(createPayload))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode createdJson = objectMapper.readTree(createResult.getResponse().getContentAsString());
        long createdId = createdJson.get("id").asLong();
        assertTrue(createdId > 0);

        String updatePayload = "{\"amount\":55.0,\"description\":\"Updated Lunch\",\"credit\":false,\"category\":{\"id\":" + catA.getId() + "}}";
        mockMvc.perform(put("/expenses/edit/" + createdId)
                .header("Authorization", basicAuthHeader("usera@example.com", "passA"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(updatePayload))
                .andExpect(status().isOk());

        Expense updated = expenseRepository.findById(createdId).orElseThrow();
        assertEquals(55.0, updated.getAmount());
        assertEquals("Updated Lunch", updated.getDescription());

        mockMvc.perform(delete("/expenses/delete/" + createdId)
                .header("Authorization", basicAuthHeader("usera@example.com", "passA")))
                .andExpect(status().isOk());

        assertTrue(expenseRepository.findById(createdId).isEmpty());
    }
}
