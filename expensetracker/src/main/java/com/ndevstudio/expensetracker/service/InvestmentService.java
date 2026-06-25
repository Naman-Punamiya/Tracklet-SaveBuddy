package com.ndevstudio.expensetracker.service;

import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.entity.Investment;
import com.ndevstudio.expensetracker.entity.User;
import com.ndevstudio.expensetracker.repository.BookRepository;
import com.ndevstudio.expensetracker.repository.InvestmentRepository;
import com.ndevstudio.expensetracker.repository.UserRepository;
import jakarta.persistence.criteria.CriteriaBuilder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

import java.util.List;

public class InvestmentService {
    private InvestmentRepository investmentRepository;
    private UserRepository userRepository;

    @Autowired
    InvestmentService(InvestmentRepository investmentRepository, UserRepository userRepository) {
        this.investmentRepository = investmentRepository;
        this.userRepository = userRepository;
    }

    public ResponseEntity<List<Investment>> readAllInvestment(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        List<Investment> investments = investmentRepository.findByUser(user);
        return new ResponseEntity<>(investments, HttpStatus.OK);
    }

    public ResponseEntity<Investment> createInvestment(Authentication authentication, Investment newInvestment) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        newInvestment.setUser(user);
        Investment investment = investmentRepository.save(newInvestment);
        return new ResponseEntity<>(investment, HttpStatus.CREATED);
    }

    public ResponseEntity<Investment> updateInvestment(Authentication authentication, long id, Investment newInvestment) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Investment oldInvestment = investmentRepository.findById(id).orElse(null);
        if (oldInvestment == null) {
            return new ResponseEntity<>(null, HttpStatus.NOT_FOUND);
        }
        if (!(oldInvestment.getUser().getId() == user.getId())) {
            return new ResponseEntity<>(
                    null,
                    HttpStatus.UNAUTHORIZED
            );
        }
        oldInvestment.setAmount(newInvestment.getAmount());
        oldInvestment.setDescription(newInvestment.getDescription());
        oldInvestment.setDate(newInvestment.getDate());
        investmentRepository.save(oldInvestment);
        return new ResponseEntity<>(oldInvestment, HttpStatus.OK);
    }

    public ResponseEntity<Investment> deleteInvestment(Authentication authentication, long id) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email).orElseThrow();
        Investment investment = investmentRepository.findById(id).orElse(null);
        if (investment == null) {
            return new ResponseEntity<>(HttpStatus.NOT_FOUND);
        }
        if (investment.getUser().getId() != user.getId()) {
            return new ResponseEntity<>(HttpStatus.UNAUTHORIZED);
        }
        investmentRepository.delete(investment);
        return new ResponseEntity<>(investment, HttpStatus.OK);
    }
}
