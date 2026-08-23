package com.ndevstudio.expensetracker.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/health")
public class HealthController {

    private final JdbcTemplate jdbcTemplate;

    public HealthController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/db")
    public ResponseEntity<Map<String, Object>> databaseHealth() {

        Integer result = jdbcTemplate.queryForObject("SELECT 1", Integer.class);

        jdbcTemplate.update("INSERT INTO database_heartbeat (created_at) VALUES (NOW())");

        jdbcTemplate.update("DELETE FROM database_heartbeat " + "WHERE created_at < NOW() - INTERVAL '7 days'");

        return ResponseEntity.ok(Map.of("status", "UP", "database", result == 1 ? "CONNECTED" : "UNKNOWN", "timestamp", Instant.now().toString()));
    }
}