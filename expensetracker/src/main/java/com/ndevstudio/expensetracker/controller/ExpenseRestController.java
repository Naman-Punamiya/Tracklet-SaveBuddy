package com.ndevstudio.expensetracker.controller;

import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.service.ExpenseService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/expenses")
public class ExpenseRestController {
    private final ExpenseService expenseService;

    @Autowired
    public ExpenseRestController(ExpenseService expenseService) {
        this.expenseService = expenseService;
    }

    @GetMapping("/readAll")
    public ResponseEntity<List<Expense>> getAllExpenses(Authentication authentication) {
        return expenseService.readAllExpenses(authentication);
    }

    @GetMapping("/book/{id}")
    public ResponseEntity<List<Expense>> getExpensesByBook(@PathVariable long id, Authentication authentication) {
        return expenseService.readExpensesByBook(id, authentication);
    }

    @PostMapping("/create")
    public ResponseEntity<?> createNewExpense(@RequestBody Expense e, Authentication authentication) {
        return expenseService.createExpense(e, authentication);
    }

    @PutMapping("/edit/{id}")
    public ResponseEntity<?> editExistingExpense(@RequestBody Expense e, @PathVariable long id, Authentication authentication) {
        return expenseService.updateExpense(e, id, authentication);
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteExpense(@PathVariable long id, Authentication authentication) {
        return expenseService.deleteExpense(id, authentication);
    }
}
