package com.ndevstudio.expensetracker.repository;

import com.ndevstudio.expensetracker.entity.Investment;
import com.ndevstudio.expensetracker.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface InvestmentRepository extends JpaRepository<Investment, Long> {
    List<Investment> findByUser(User user);
    void deleteByUser(User user);
}
