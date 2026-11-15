package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.Investment;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.BookRepository;
import com.ndevstudio.expensetracker.repository.CategoryRepository;
import com.ndevstudio.expensetracker.repository.ExpenseRepository;
import com.ndevstudio.expensetracker.repository.InvestmentRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final ExpenseRepository expenseRepository;
    private final InvestmentRepository investmentRepository;
    private final CategoryRepository categoryRepository;
    private final BookRepository bookRepository;

    @Autowired
    public UserService(
            UserRepository userRepository,
            ExpenseRepository expenseRepository,
            InvestmentRepository investmentRepository,
            CategoryRepository categoryRepository,
            BookRepository bookRepository
    ) {
        this.userRepository = userRepository;
        this.expenseRepository = expenseRepository;
        this.investmentRepository = investmentRepository;
        this.categoryRepository = categoryRepository;
        this.bookRepository = bookRepository;
    }

    public Optional<User> findUserByMail(String email) {
        return userRepository.findByEmail(email);
    }

    /**
     * Atomically deletes the authenticated user's account and all associated financial records.
     * All deletions are strictly scoped to the authenticated user's identity.
     * Expenses are deleted only if owned by the authenticated user.
     *
     * Deletion follows the strict dependency order:
     * 1. Expenses owned by user (scoped by book, category, and direct ownership)
     * 2. Investments owned by user
     * 3. Categories owned by user
     * 4. Books owned by user
     * 5. User account
     *
     * If another user's expense references this user's book or category, the foreign key constraint
     * will block the deletion of that book/category, causing a full transaction rollback.
     *
     * @param email The authenticated user's email resolved from SecurityContext
     */
    @Transactional(rollbackFor = Exception.class)
    public void deleteUserAccount(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Step 1: Delete expenses owned by user associated with their books
        List<Book> books = bookRepository.findByUser(user);
        for (Book book : books) {
            List<Expense> bookExpenses = expenseRepository.findByUserAndBook(user, book);
            if (!bookExpenses.isEmpty()) {
                expenseRepository.deleteAll(bookExpenses);
            }
        }

        // Step 2: Delete expenses owned by user associated with their categories
        List<Category> categories = categoryRepository.findByUser(user);
        for (Category category : categories) {
            List<Expense> catExpenses = expenseRepository.findByUserAndCategory(user, category);
            if (!catExpenses.isEmpty()) {
                expenseRepository.deleteAll(catExpenses);
            }
        }

        // Step 3: Delete any remaining expenses directly owned by user
        List<Expense> userExpenses = expenseRepository.findByUser(user);
        if (!userExpenses.isEmpty()) {
            expenseRepository.deleteAll(userExpenses);
        }

        // Step 4: Delete all investments owned by user
        List<Investment> investments = investmentRepository.findByUser(user);
        if (!investments.isEmpty()) {
            investmentRepository.deleteAll(investments);
        }

        // Step 5: Delete all categories owned by user
        if (!categories.isEmpty()) {
            categoryRepository.deleteAll(categories);
        }

        // Step 6: Delete all books owned by user
        if (!books.isEmpty()) {
            bookRepository.deleteAll(books);
        }

        // Step 7: Delete user record
        userRepository.delete(user);
    }
}
