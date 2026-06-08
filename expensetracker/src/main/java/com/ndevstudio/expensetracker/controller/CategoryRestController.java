package com.ndevstudio.expensetracker.controller;

import com.ndevstudio.expensetracker.entity.Category;
import com.ndevstudio.expensetracker.entity.Expense;
import com.ndevstudio.expensetracker.service.CategoryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/categories")
public class CategoryRestController {

    private final CategoryService categoryService;

    @Autowired
    public CategoryRestController(CategoryService categoryService) {
        this.categoryService = categoryService;
    }

    @GetMapping("/readAll")
    public ResponseEntity<List<Category>> readAll(Authentication authentication) {
        return categoryService.readAllCategory(authentication);
    }

    @PostMapping("/create")
    public ResponseEntity<Category> create(@RequestBody Category category, Authentication authentication) {
        return categoryService.createCategory(category, authentication);
    }

    @PutMapping("/edit/{id}")
    public ResponseEntity<Category> update(@PathVariable long id, @RequestBody Category category, Authentication authentication) {
        return categoryService.updateCategory(category, id, authentication);
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<String> delete(@PathVariable long id, Authentication authentication) {
        return categoryService.deleteCategory(id, authentication);
    }
}