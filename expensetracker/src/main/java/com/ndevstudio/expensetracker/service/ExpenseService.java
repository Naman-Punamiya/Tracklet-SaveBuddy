package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.repository.ExpenseRepository;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class ExpenseService {
    private ExpenseRepository expenseRepository;

    @Autowired
    ExpenseService(ExpenseRepository expenseRepository){
        this.expenseRepository = expenseRepository;
    }

    //Read
    public ResponseEntity<List<Expense>> readAllExpenses(){
        List<Expense> expenses = expenseRepository.findAll();
        return new ResponseEntity<>(expenses,HttpStatus.OK);
    }

    //ReadByBook
    public ResponseEntity<List<Expense>> readExpensesByBook(Long bookId){
        List<Expense> expenses = expenseRepository.findByBookId(bookId);
        return new ResponseEntity<>(expenses,HttpStatus.OK);
    }

    //Create
    public ResponseEntity<Expense> createExpense(Expense newExpense){
        Expense e = expenseRepository.save(newExpense);
        return new ResponseEntity<>(e,HttpStatus.CREATED);
    }

    //Update
    public ResponseEntity<Expense> updateExpense(Expense newExpense,long id){
        Expense oldExpense = expenseRepository.findById(id).orElse(null);
        if(oldExpense != null){
            oldExpense.setAmount(newExpense.getAmount());
            oldExpense.setDescription(newExpense.getDescription());
            expenseRepository.save(oldExpense);
            return new ResponseEntity<>(oldExpense,HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }

    //Delete
    public ResponseEntity<Expense> deleteExpense(long id){
        Expense e = expenseRepository.findById(id).orElse(null);
        if(e != null){
            expenseRepository.delete(e);
            return new ResponseEntity<>(e,HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }
}
