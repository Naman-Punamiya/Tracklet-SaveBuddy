package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Book;
import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.BookRepository;
import com.ndevstudio.expensetracker.repository.CategoryRepository;
import com.ndevstudio.expensetracker.repository.ExpenseRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ExpenseService {
    private final ExpenseRepository expenseRepository;
    private final UserRepository userRepository;
    private final BookRepository bookRepository;
    private final CategoryRepository categoryRepository;

    @Autowired
    public ExpenseService(
            ExpenseRepository expenseRepository,
            UserRepository userRepository,
            BookRepository bookRepository,
            CategoryRepository categoryRepository
    ) {
        this.expenseRepository = expenseRepository;
        this.userRepository = userRepository;
        this.bookRepository = bookRepository;
        this.categoryRepository = categoryRepository;
    }

    // Read all expenses belonging exclusively to the authenticated user
    public ResponseEntity<List<Expense>> readAllExpenses(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        List<Expense> expenses = expenseRepository.findByUser(user);
        return new ResponseEntity<>(expenses, HttpStatus.OK);
    }

    // Read expenses for a book, ensuring the book belongs to the authenticated user
    public ResponseEntity<List<Expense>> readExpensesByBook(Long bookId, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Book book = bookRepository.findByIdAndUser(bookId, user).orElse(null);
        if (book == null) {
            return new ResponseEntity<>(HttpStatus.NOT_FOUND);
        }
        List<Expense> expenses = expenseRepository.findByUserAndBook(user, book);
        return new ResponseEntity<>(expenses, HttpStatus.OK);
    }

    // Create expense with verified owner and verified book/category relationships
    public ResponseEntity<?> createExpense(Expense newExpense, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();

        // Prevent client-supplied ID from performing merge/overwrite
        newExpense.setId(0);

        // Validate Book if supplied
        if (newExpense.getBook() != null && newExpense.getBook().getId() != null) {
            Long bookId = newExpense.getBook().getId();
            Book book = bookRepository.findByIdAndUser(bookId, user).orElse(null);
            if (book == null) {
                return new ResponseEntity<>("Invalid or unauthorized book", HttpStatus.BAD_REQUEST);
            }
            newExpense.setBook(book);
        } else {
            newExpense.setBook(null);
        }

        // Validate Category if supplied
        if (newExpense.getCategory() != null && newExpense.getCategory().getId() != null) {
            Long catId = newExpense.getCategory().getId();
            Category category = categoryRepository.findByIdAndUser(catId, user).orElse(null);
            if (category == null) {
                return new ResponseEntity<>("Invalid or unauthorized category", HttpStatus.BAD_REQUEST);
            }
            newExpense.setCategory(category);
        } else {
            newExpense.setCategory(null);
        }

        newExpense.setUser(user);
        Expense saved = expenseRepository.save(newExpense);
        return new ResponseEntity<>(saved, HttpStatus.CREATED);
    }

    // Update expense with strict ownership and relationship verification
    public ResponseEntity<?> updateExpense(Expense newExpense, long id, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();

        Expense oldExpense = expenseRepository.findByIdAndUser(id, user).orElse(null);
        if (oldExpense == null) {
            return new ResponseEntity<>(HttpStatus.NOT_FOUND);
        }

        // Validate Category if supplied
        if (newExpense.getCategory() != null) {
            if (newExpense.getCategory().getId() != null) {
                Long catId = newExpense.getCategory().getId();
                Category category = categoryRepository.findByIdAndUser(catId, user).orElse(null);
                if (category == null) {
                    return new ResponseEntity<>("Invalid or unauthorized category", HttpStatus.BAD_REQUEST);
                }
                oldExpense.setCategory(category);
            } else {
                oldExpense.setCategory(null);
            }
        }

        // Validate Book if supplied (if null in payload, keep existing book)
        if (newExpense.getBook() != null) {
            if (newExpense.getBook().getId() != null) {
                Long bookId = newExpense.getBook().getId();
                Book book = bookRepository.findByIdAndUser(bookId, user).orElse(null);
                if (book == null) {
                    return new ResponseEntity<>("Invalid or unauthorized book", HttpStatus.BAD_REQUEST);
                }
                oldExpense.setBook(book);
            } else {
                oldExpense.setBook(null);
            }
        }

        oldExpense.setAmount(newExpense.getAmount());
        oldExpense.setDescription(newExpense.getDescription());
        oldExpense.setCredit(newExpense.isCredit());
        oldExpense.setDate(newExpense.getDate());
        // Explicitly preserve ownership: oldExpense.getUser() is never changed.

        Expense saved = expenseRepository.save(oldExpense);
        return new ResponseEntity<>(saved, HttpStatus.OK);
    }

    // Delete expense ensuring caller ownership
    public ResponseEntity<?> deleteExpense(long id, Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();

        Expense e = expenseRepository.findByIdAndUser(id, user).orElse(null);
        if (e != null) {
            expenseRepository.delete(e);
            return new ResponseEntity<>(e, HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }
}
