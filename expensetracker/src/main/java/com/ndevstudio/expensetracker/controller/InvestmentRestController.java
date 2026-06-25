package com.ndevstudio.expensetracker.controller;

import com.ndevstudio.expensetracker.entity.Book;

import com.ndevstudio.expensetracker.entity.Investment;
import com.ndevstudio.expensetracker.service.InvestmentService;
import org.springframework.beans.factory.annotation.Autowired;

import org.springframework.http.ResponseEntity;

import org.springframework.security.core.Authentication;

import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/investment")
public class InvestmentRestController {

    private final InvestmentService investmentService;

    @Autowired
    public InvestmentRestController(InvestmentService investmentService) {
        this.investmentService = investmentService;
    }

    // READ USER BOOKS
    @GetMapping("/readAll")
    public ResponseEntity<List<Investment>> getAllInvestment(Authentication authentication){
        return investmentService.readAllInvestment(authentication);
    }

    // CREATE BOOK
    @PostMapping("/create")
    public ResponseEntity<Investment> createNewInvestment(@RequestBody Investment investment, Authentication authentication) {
        return investmentService.createInvestment(authentication,investment);
    }

    // UPDATE BOOK
    @PutMapping("/edit/{id}")
    public ResponseEntity<?> editExistingInvestment(@RequestBody Investment investment, @PathVariable long id,Authentication authentication) {
        return investmentService.updateInvestment(authentication,id,investment);
    }

    // DELETE BOOK
    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteInvestment(@PathVariable long id, Authentication authentication) {
        return investmentService.deleteInvestment(authentication,id);
    }
}