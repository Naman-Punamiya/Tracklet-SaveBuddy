package com.ndevstudio.expensetracker.controller;

import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.repository.ExpenseRepository;
import com.ndevstudio.expensetracker.service.ExpenseService;
import org.apache.coyote.Response;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/expenses")
public class ExpenseRestController {
    ExpenseService expenseService;

    @Autowired
    public ExpenseRestController(ExpenseService expenseService) {
        this.expenseService = expenseService;
    }

    @GetMapping("/readAll")
    ResponseEntity<List<Expense>> getAllExpenses() {
        return expenseService.readAllExpenses();
    }

    @GetMapping("/book/{id}")
    ResponseEntity<List<Expense>> getExpensesByBook(@PathVariable long id) {
        return expenseService.readExpensesByBook(id);
    }

    @PostMapping("/create")
    ResponseEntity<Expense> createNewExpense(@RequestBody Expense e) {
        return expenseService.createExpense(e);
    }

    @PutMapping("/edit/{id}")
    ResponseEntity<Expense> editExistingExpense(@RequestBody Expense e, @PathVariable long id) {
        return expenseService.updateExpense(e, id);
    }

    @DeleteMapping("/delete/{id}")
    ResponseEntity<Expense> deleteExpense(@PathVariable long id) {
        return expenseService.deleteExpense(id);
    }
}
